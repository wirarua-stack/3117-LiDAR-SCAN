import SwiftUI
import RealityKit

struct CaptureScreen: View {
    @Environment(\.dismiss) private var dismiss
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
                    Text("Mesh anchors: \(scan.meshCount)").font(.caption).foregroundStyle(.white)
                    Text(scan.trackingStatus).font(.caption).foregroundStyle(.white)
                    TextField("Project name", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 350)
                    Text(scan.measurementText).font(.caption).foregroundStyle(.white)
                    HStack { Button("Mark point") { scan.markMeasurementPoint() }; Button("Pause") { scan.pause() }; Button("Resume") { scan.resume() }; Button("Save scan") { finish() }.buttonStyle(.borderedProminent).disabled(scan.meshCount == 0) }
                }.padding()
            }
            .navigationTitle("Live LiDAR Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if scan.meshCount > 0 { confirmingDiscard = true }
                    else { dismiss() }
                }
            } }
            .interactiveDismissDisabled(scan.meshCount > 0)
            .confirmationDialog("Discard this unsaved scan?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard scan", role: .destructive) { dismiss() }
                Button("Keep scanning", role: .cancel) { }
            }
            .onAppear { scan.requestCameraAndStart() }
            .onDisappear { scan.pause() }
            .alert("Cannot save scan", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    private func finish() {
        scan.finish()
        do {
            try library.save(name: name, samples: scan.snapshot())
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ARViewContainer: UIViewRepresentable { let view: ARView; func makeUIView(context: Context) -> ARView { view }; func updateUIView(_ uiView: ARView, context: Context) {} }
