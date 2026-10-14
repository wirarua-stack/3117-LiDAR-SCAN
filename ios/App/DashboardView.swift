import SwiftUI
import SceneKit

struct DashboardView: View {
    @EnvironmentObject private var library: ProjectLibrary
    @State private var showingCapture = false

    var body: some View {
        NavigationSplitView {
            List {
                Section("Projects") {
                    ForEach(library.projects) { project in
                        NavigationLink { SavedModelView(project: project) } label: {
                            VStack(alignment: .leading) {
                                Text(project.name)
                                Text(project.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: library.delete)
                }
            }
            .navigationTitle("3117 LiDAR SCAN")
            .toolbar { Button("New Scan", systemImage: "plus") { showingCapture = true } }
        } detail: {
            ContentUnavailableView("Select a project or start a scan", systemImage: "cube.transparent")
        }
        .sheet(isPresented: $showingCapture) { CaptureScreen() }
        .tint(.orange)
        .preferredColorScheme(.dark)
        .alert("Project library", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK") { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct SavedModelView: View {
    let project: ScanProject
    @EnvironmentObject private var library: ProjectLibrary
    @State private var scene: SCNScene?
    @State private var errorMessage: String?
    @State private var exportURL: URL?
    @State private var measurement = "Tap two surfaces to measure. Drag to orbit; pinch to zoom."

    var body: some View {
        VStack {
            if let scene { MeshSceneView(scene: scene, measurement: $measurement) }
            else { ContentUnavailableView("Model unavailable", systemImage: "cube") }
            Text(measurement).padding()
            Text("Estimated surface distance • validate against site references").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Export OBJ") {
                    do { exportURL = try library.export(project) }
                    catch { errorMessage = error.localizedDescription }
                }.disabled(scene == nil)
                if let exportURL { ShareLink("Share OBJ", item: exportURL) }
            }.padding()
        }
        .navigationTitle(project.name)
        .task(id: project.id) {
            do { scene = try buildScene(library.load(project)) }
            catch { errorMessage = error.localizedDescription }
        }
        .alert("Model operation failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func buildScene(_ samples: [MeshSample]) throws -> SCNScene {
        let scene = SCNScene()
        for sample in samples {
            try sample.validate()
            let vertices = sample.vertices.map { vertex -> SCNVector3 in
                let p = sample.transform.transform(vertex)
                return SCNVector3(p.x, p.y, p.z)
            }
            let indices = sample.triangles.flatMap { [$0.a, $0.b, $0.c] }
            let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemOrange
            material.isDoubleSided = true
            geometry.materials = [material]
            scene.rootNode.addChildNode(SCNNode(geometry: geometry))
        }
        return scene
    }
}

private struct MeshSceneView: UIViewRepresentable {
    let scene: SCNScene
    @Binding var measurement: String
    func makeCoordinator() -> Coordinator { Coordinator(measurement: $measurement) }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.03, green: 0.06, blue: 0.12, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.scene = scene
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        if view.scene !== scene { view.scene = scene; context.coordinator.first = nil }
    }
    final class Coordinator: NSObject {
        var first: SIMD3<Float>?
        var measurement: Binding<String>
        init(measurement: Binding<String>) { self.measurement = measurement }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  let hit = view.hitTest(gesture.location(in: view), options: nil).first else { return }
            let p = hit.worldCoordinates
            let point = SIMD3<Float>(p.x, p.y, p.z)
            if let first {
                measurement.wrappedValue = Measurement.display(Measurement.distanceMetres(from: first, to: point))
                self.first = nil
            } else { first = point; measurement.wrappedValue = "First point selected. Tap a second surface." }
        }
    }
}
