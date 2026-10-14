import ARKit
import Combine
import RealityKit
import AVFoundation

@MainActor
final class ScanCoordinator: NSObject, ObservableObject, ARSessionDelegate {
    @Published var status = "Preparing LiDAR"
    @Published var isSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    @Published private(set) var meshCount = 0
    @Published private(set) var measurementText = "Aim the center reticle, then mark two points."
    let arView = ARView(frame: .zero)
    private var samples: [UUID: MeshSample] = [:]

    func requestCameraAndStart() {
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
        guard isSupported else { status = "This device does not support LiDAR mesh reconstruction."; return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.environmentTexturing = .automatic
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.session.run(configuration, options: reset ? [.resetTracking, .removeExistingAnchors] : [])
        status = "Scanning — move slowly around the subject"
    }
    func pause() { arView.session.pause(); status = "Scan paused" }
    func resume() { startSession(reset: false) }
    func finish() { arView.session.pause(); status = "Scan ready: \(samples.count) mesh anchors" }
    func archive() throws -> Data { try JSONEncoder().encode(Array(samples.values)) }
    func snapshot() -> [MeshSample] { Array(samples.values) }
    private var firstMeasurementPoint: SIMD3<Float>?

    func markMeasurementPoint() {
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
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { ingest(anchors) }
    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let ids = anchors.map(\.identifier)
        Task { @MainActor in
            for id in ids { samples.removeValue(forKey: id) }
            meshCount = samples.count
        }
    }
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in status = message }
    }
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in status = "Capture interrupted. Return and resume." }
    }
    nonisolated private func ingest(_ anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }
        let converted = meshAnchors.map(MeshSample.init)
        Task { @MainActor in
            for (anchor, sample) in zip(meshAnchors, converted) { samples[anchor.identifier] = sample }
            meshCount = samples.count
        }
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
