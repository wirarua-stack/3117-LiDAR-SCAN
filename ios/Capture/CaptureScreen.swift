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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ARViewContainer(view: scan.arView).ignoresSafeArea()
                    .overlay { Image(systemName: "plus").font(.title).foregroundStyle(.orange).allowsHitTesting(false) }
                VStack(spacing: 12) {
                    Text(scan.status).padding(10).background(.black.opacity(0.72), in: Capsule()).foregroundStyle(.white)
                    Text("Mesh anchors: \(scan.meshCount) • Vertices: \(scan.vertexCount) / 500000").font(.caption).foregroundStyle(.white)
                    if let operation = library.operation { ProgressView(operation).tint(.orange) }
                    Text(scan.trackingStatus).font(.caption).foregroundStyle(.white)
                    TextField("Project name", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 350)
                    Text(scan.measurementText).font(.caption).foregroundStyle(.white)
                    HStack { Button("Mark point") { scan.markMeasurementPoint() }; Button("Pause") { scan.pause() }; Button("Resume") { scan.resume() }; Button("Save scan") { finish() }.buttonStyle(.borderedProminent).disabled(scan.meshCount == 0) }
                }.padding().disabled(library.isBusy)
            }
            .navigationTitle("Live LiDAR Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if scan.meshCount > 0 { confirmingDiscard = true }
                    else { dismiss() }
                }.disabled(library.isBusy)
            } }
            .interactiveDismissDisabled(scan.meshCount > 0 || library.isBusy)
            .confirmationDialog("Discard this unsaved scan?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard scan", role: .destructive) { dismiss() }
                Button("Keep scanning", role: .cancel) { }
            }
            .onAppear { scan.requestCameraAndStart() }
            .onDisappear { scan.close() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { scan.pause(reason: "App inactive. Return to the scanned area, then tap Resume.") }
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
        guard !library.isBusy else { return }
        let samples = scan.snapshot()
        Task {
            do {
                try await library.saveInBackground(name: name, samples: samples)
                dismiss()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

private struct ARViewContainer: UIViewRepresentable { let view: ARView; func makeUIView(context: Context) -> ARView { view }; func updateUIView(_ uiView: ARView, context: Context) {} }
