import ARKit
import Combine
import RealityKit
import AVFoundation
import CoreVideo

@MainActor
final class ScanCoordinator: NSObject, ObservableObject, ARSessionDelegate {
    @Published var status = "Preparing LiDAR"
    @Published var isSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    @Published private(set) var meshCount = 0
    @Published private(set) var vertexCount = 0
    @Published private(set) var pointCount = 0
    @Published private(set) var depthFrameCount = 0
    @Published private(set) var depthStatus = "Waiting for high-confidence LiDAR depth"
    var hasCapture: Bool { meshCount > 0 || pointCount > 0 || depthTask != nil }
    private let depthStore = DepthFusionStore()
    private var depthTask: Task<Void, Never>?
    private var lastDepthTimestamp: TimeInterval = -.infinity
    @Published private(set) var isScanning = false
    private var triangleCount = 0
    private var closed = false
    private var started = false
    private var capacityReached = false
    private var sessionFailed = false
    private let budget = CaptureBudget()
    @Published private(set) var trackingStatus = "Waiting for tracking"
    @Published private(set) var measurementText = "Aim the center reticle, then mark two points."
    let arView = ARView(frame: .zero)
    private var samples: [UUID: MeshSample] = [:]

    override init() {
        super.init()
        // Prime thermal monitoring before CaptureScreen subscribes to notifications.
        _ = ProcessInfo.processInfo.thermalState
    }

    func requestCameraAndStart() {
        guard !started, !closed else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startSession(reset: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.startSession(reset: true) }
                    else { self.status = "Camera permission is required to scan." }
                }
            }
        default: status = "Camera permission is denied. Enable it in Settings to scan."
        }
    }
    private func startSession(reset: Bool) {
        guard !closed, !capacityReached, !sessionFailed,
              UIApplication.shared.applicationState == .active else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            status = "Camera permission is required to scan."; return
        }
        guard ProcessInfo.processInfo.thermalState != .serious,
              ProcessInfo.processInfo.thermalState != .critical else {
            pause(reason: "Device too warm. Let it cool before resuming."); return
        }
        guard isSupported else { status = "This device does not support LiDAR scene depth and mesh reconstruction."; return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics.insert(.sceneDepth)
        configuration.environmentTexturing = .automatic
        arView.session.delegate = self
        arView.session.delegateQueue = .main
        arView.automaticallyConfigureSession = false
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.session.run(configuration, options: reset ? [.resetTracking, .removeExistingAnchors] : [])
        started = true
        isScanning = true
        status = "Scanning — move slowly around the subject"
    }
    func pause(reason: String = "Scan paused. Resume when ready.") {
        isScanning = false
        firstMeasurementPoint = nil
        measurementText = "Aim the center reticle, then mark two points."
        arView.session.pause(); status = reason
    }
    func resume() { startSession(reset: !started) }
    func finish() { pause(reason: "Scan ready: \(samples.count) mesh anchors") }
    func close() { closed = true; pause(); arView.session.delegate = nil }
    func thermalStateChanged() {
        if isScanning && (ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical) {
            pause(reason: "Device too warm. Let it cool, then tap Resume.")
        }
    }
    func memoryWarning() {
        capacityReached = true
        pause(reason: "Memory pressure. Save this scan and start a smaller scan.")
    }
    func snapshot() async -> [MeshSample] {
        // Finish the one accepted frame before saving; never retain ARFrame/pixel buffers in a Task.
        await depthTask?.value
        let meshes = Array(samples.values)
        if let cloud = await depthStore.snapshot() { return meshes + [cloud] }
        return meshes
    }
    private var firstMeasurementPoint: SIMD3<Float>?

    func markMeasurementPoint() {
        guard isScanning, case .normal = arView.session.currentFrame?.camera.trackingState else {
            measurementText = "Resume and wait for normal tracking before measuring."; return
        }
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        guard let hit = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .any).first else {
            measurementText = "No surface at reticle — move closer and try again."
            return
        }
        let point = SIMD3(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z)
        if let first = firstMeasurementPoint {
            measurementText = Measurement.display(Measurement.distanceMetres(from: first, to: point))
            firstMeasurementPoint = nil
        } else {
            firstMeasurementPoint = point
            measurementText = "First point marked. Aim at the second point and mark again."
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { ingest(anchors) }
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        MainActor.assumeIsolated {
            guard isScanning, depthTask == nil, frame.timestamp - lastDepthTimestamp >= 0.2 else { return }
            guard case .normal = frame.camera.trackingState else {
                depthStatus = "Depth paused until tracking is normal"; return
            }
            lastDepthTimestamp = frame.timestamp
            guard let sample = DepthFrameSampler.sample(frame) else {
                depthStatus = "No supported depth/confidence/color frame yet"; return
            }
            depthTask = Task {
                let result = await depthStore.integrate(sample)
                depthTask = nil
                guard !closed else { return }
                pointCount = result.count; depthFrameCount = result.frames
                depthStatus = result.count > 0 ? "Depth + RGB • 2 cm voxels • high confidence only" : "Aim at a nearby textured surface (0.2–5 m)"
                if result.full {
                    capacityReached = true
                    pause(reason: "Point-cloud limit reached (200000). Save and start another scan.")
                }
            }
        }
    }
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { ingest(anchors) }
    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let ids = anchors.map(\.identifier)
        MainActor.assumeIsolated {
            guard isScanning else { return }
            for id in ids {
                if let removed = samples.removeValue(forKey: id) {
                    vertexCount -= removed.vertices.count; triangleCount -= removed.triangles.count
                }
            }
            meshCount = samples.count
        }
    }
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        MainActor.assumeIsolated {
            sessionFailed = true
            pause(reason: "Session failed: \(message). Save this scan and start a new one.")
        }
    }
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        MainActor.assumeIsolated { pause(reason: "Capture interrupted. Return to the scanned area, then tap Resume.") }
    }
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let text: String
        switch camera.trackingState {
        case .normal: text = "Tracking normal"
        case .notAvailable: text = "Tracking unavailable"
        case .limited(let reason):
            switch reason {
            case .initializing: text = "Initializing — move slowly"
            case .excessiveMotion: text = "Slow down to restore tracking"
            case .insufficientFeatures: text = "Aim at a surface with more visual detail"
            case .relocalizing: text = "Return to a previously scanned area"
            @unknown default: text = "Tracking limited"
            }
        }
        Task { @MainActor in trackingStatus = text }
    }
    nonisolated private func ingest(_ anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }
        // Delegate queue is explicitly main: copy buffers synchronously, with no queued mesh Tasks.
        MainActor.assumeIsolated {
            guard isScanning else { return }
            for anchor in meshAnchors {
                let old = samples[anchor.identifier]
                let vertices = vertexCount - (old?.vertices.count ?? 0) + anchor.geometry.vertices.count
                let triangles = triangleCount - (old?.triangles.count ?? 0) + anchor.geometry.faces.count
                guard budget.allows(vertices: vertices, triangles: triangles, anchors: samples.count + (old == nil ? 1 : 0)) else {
                    capacityReached = true
                    pause(reason: "Scan size limit reached. Save this scan and start another.")
                    break
                }
                samples[anchor.identifier] = MeshSample(anchor: anchor)
                vertexCount = vertices; triangleCount = triangles
            }
            meshCount = samples.count
        }
    }
}

/// Copies a small, bounded sample while ARKit owns the frame. Buffer row padding is respected.
private enum DepthFrameSampler {
    static func sample(_ frame: ARFrame) -> DepthFrameSample? {
        guard let depth = frame.sceneDepth, let confidence = depth.confidenceMap else { return nil }
        let map = depth.depthMap, color = frame.capturedImage
        let width = CVPixelBufferGetWidth(map), height = CVPixelBufferGetHeight(map)
        let colorFormat = CVPixelBufferGetPixelFormatType(color)
        guard CVPixelBufferGetPixelFormatType(map) == kCVPixelFormatType_DepthFloat32,
              CVPixelBufferGetPixelFormatType(confidence) == kCVPixelFormatType_OneComponent8,
              width > 0, height > 0, width <= 2048, height <= 2048,
              ((width + 3) / 4) * ((height + 3) / 4) <= 20_000,
              CVPixelBufferGetWidth(confidence) == width, CVPixelBufferGetHeight(confidence) == height,
              CVPixelBufferGetPlaneCount(color) == 2,
              colorFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || colorFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange else { return nil }
        guard CVPixelBufferLockBaseAddress(map, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard CVPixelBufferLockBaseAddress(confidence, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        guard CVPixelBufferLockBaseAddress(color, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(color, .readOnly) }
        guard let depthBase = CVPixelBufferGetBaseAddress(map), let confidenceBase = CVPixelBufferGetBaseAddress(confidence),
              let yBase = CVPixelBufferGetBaseAddressOfPlane(color, 0), let uvBase = CVPixelBufferGetBaseAddressOfPlane(color, 1) else { return nil }
        let depthStride = CVPixelBufferGetBytesPerRow(map), confidenceStride = CVPixelBufferGetBytesPerRow(confidence)
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(color, 0), uvStride = CVPixelBufferGetBytesPerRowOfPlane(color, 1)
        let yw = CVPixelBufferGetWidthOfPlane(color, 0), yh = CVPixelBufferGetHeightOfPlane(color, 0)
        let uvw = CVPixelBufferGetWidthOfPlane(color, 1), uvh = CVPixelBufferGetHeightOfPlane(color, 1)
        guard yw > 0, yh > 0, uvw > 0, uvh > 0,
              depthStride >= width * 4, confidenceStride >= width, yStride >= yw, uvStride >= uvw * 2 else { return nil }
        var pixels: [DepthPixel] = []
        pixels.reserveCapacity(((width + 3) / 4) * ((height + 3) / 4))
        for y in stride(from: 0, to: height, by: 4) {
            let depths = depthBase.advanced(by: y * depthStride).assumingMemoryBound(to: Float.self)
            let confidences = confidenceBase.advanced(by: y * confidenceStride).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: 0, to: width, by: 4) {
                let z = depths[x]
                guard confidences[x] == 2, z.isFinite, z >= 0.2, z <= 5 else { continue }
                // Native sensor coordinates, not screen/display orientation.
                let px = min(yw - 1, x * yw / width), py = min(yh - 1, y * yh / height)
                let ux = min(uvw - 1, x * uvw / width), uy = min(uvh - 1, y * uvh / height)
                let luma = yBase.advanced(by: py * yStride + px).assumingMemoryBound(to: UInt8.self).pointee
                let chroma = uvBase.advanced(by: uy * uvStride + ux * 2).assumingMemoryBound(to: UInt8.self)
                let rgb = PointRGB.yCbCr(y: luma, cb: chroma[0], cr: chroma[1], videoRange: colorFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                pixels.append(DepthPixel(x: Float(x), y: Float(y), depth: z, confidence: confidences[x], color: rgb))
            }
        }
        let resolution = frame.camera.imageResolution, intrinsics = frame.camera.intrinsics
        guard resolution.width > 0, resolution.height > 0 else { return nil }
        let sx = Float(width) / Float(resolution.width), sy = Float(height) / Float(resolution.height)
        return DepthFrameSample(fx: intrinsics.columns.0.x * sx, fy: intrinsics.columns.1.y * sy,
                                cx: intrinsics.columns.2.x * sx, cy: intrinsics.columns.2.y * sy,
                                cameraToWorld: Matrix4x4(frame.camera.transform), pixels: pixels)
    }
}

private extension MeshSample {
    init(anchor: ARMeshAnchor) {
        let geometry = anchor.geometry
        let positions = geometry.vertices
        let vertices = (0..<positions.count).map { index -> SIMD3<Float> in
            let pointer = positions.buffer.contents().advanced(by: positions.offset + positions.stride * index)
            let floats = pointer.assumingMemoryBound(to: Float.self)
            return SIMD3(floats[0], floats[1], floats[2])
        }
        let faces = geometry.faces
        let indices: [UInt32] = (0..<(faces.count * 3)).map { i in
            let pointer = faces.buffer.contents().advanced(by: faces.bytesPerIndex * i)
            return faces.bytesPerIndex == 2 ? UInt32(pointer.assumingMemoryBound(to: UInt16.self).pointee) : pointer.assumingMemoryBound(to: UInt32.self).pointee
        }
        self.init(vertices: vertices.map(Vector3.init), triangles: stride(from: 0, to: indices.count, by: 3).map { Triangle(a: indices[$0], b: indices[$0+1], c: indices[$0+2]) }, transform: Matrix4x4(anchor.transform))
    }
}
