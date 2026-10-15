import SwiftUI
import RealityKit

struct CaptureScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var library: ProjectLibrary
    @StateObject private var scan = ScanCoordinator()
    @State private var name = "Untitled Scan"
    @State private var errorMessage: String?
    @State private var confirmingDiscard = false
    @State private var captureProject = ScanProject(name: "Untitled Scan")
    @State private var checkpointStatus = "No recovery checkpoint yet"
    @State private var ending = false
    @State private var preparingArchive = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ARViewContainer(view: scan.arView).ignoresSafeArea()
                    .overlay { Image(systemName: "plus").font(.title).foregroundStyle(.orange).allowsHitTesting(false) }
                VStack(spacing: 12) {
                    Text(scan.status).padding(10).background(.black.opacity(0.72), in: Capsule()).foregroundStyle(.white)
                    Text("Mesh anchors: \(scan.meshCount) • Vertices: \(scan.vertexCount) / 500000").font(.caption).foregroundStyle(.white)
                    Text("Color points: \(scan.pointCount) / 200000 • Depth frames: \(scan.depthFrameCount)").font(.caption).foregroundStyle(.white)
                    Text(scan.depthStatus).font(.caption).foregroundStyle(.white)
                    if preparingArchive || ending { ProgressView("Preparing scan…").tint(.orange) }
                    if let operation = library.operation { ProgressView(operation).tint(.orange) }
                    Text(scan.trackingStatus).font(.caption).foregroundStyle(.white)
                    Text(checkpointStatus).font(.caption).foregroundStyle(.white)
                    TextField("Project name", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 350)
                    Text(scan.measurementText).font(.caption).foregroundStyle(.white)
                    HStack { Button("Mark point") { scan.markMeasurementPoint() }; Button("Pause") { scan.pause() }; Button("Resume") { scan.resume() }; Button("Save scan") { finish() }.buttonStyle(.borderedProminent).disabled(!scan.hasCapture) }
                }.padding().disabled(library.isBusy || ending || preparingArchive)
            }
            .navigationTitle("Live LiDAR Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if scan.hasCapture { confirmingDiscard = true }
                    else { ending = true; dismiss() }
                }.disabled(library.isBusy || ending || preparingArchive)
            } }
            .interactiveDismissDisabled(scan.hasCapture || library.isBusy || ending || preparingArchive)
            .confirmationDialog("Discard this unsaved scan?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard scan", role: .destructive) {
                    do { try library.discardDraft(captureProject.id); ending = true; dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
                Button("Keep scanning", role: .cancel) { }
            }
            .onAppear { scan.requestCameraAndStart() }
            .onDisappear { ending = true; scan.close() }
            .task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(20)) }
                    catch { return }
                    if !Task.isCancelled { await checkpoint() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    scan.pause(reason: "App inactive. Return to the scanned area, then tap Resume.")
                    Task { await checkpoint() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in scan.thermalStateChanged() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in scan.memoryWarning() }
            .alert("Cannot save scan", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    private func finish() {
        scan.finish()
        guard !library.isBusy, !ending, !preparingArchive else { return }
        ending = true
        Task {
            do {
                let samples = await scan.snapshot()
                try await library.saveInBackground(name: name, samples: samples, captureProject: captureProject)
                dismiss()
            } catch { ending = false; errorMessage = error.localizedDescription }
        }
    }
    private func checkpoint() async {
        guard !ending, scan.hasCapture, !library.isBusy, !preparingArchive else { return }
        preparingArchive = true
        defer { preparingArchive = false }
        captureProject.name = name
        do {
            let samples = await scan.snapshot()
            guard !ending, !Task.isCancelled else { return }
            try await library.checkpoint(project: captureProject, samples: samples)
            checkpointStatus = "Recovery saved at \(Date.now.formatted(date: .omitted, time: .shortened))"
        } catch { checkpointStatus = "Recovery save failed: \(error.localizedDescription)" }
    }
}

private struct ARViewContainer: UIViewRepresentable { let view: ARView; func makeUIView(context: Context) -> ARView { view }; func updateUIView(_ uiView: ARView, context: Context) {} }
