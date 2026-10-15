import SwiftUI
import SceneKit

struct DashboardView: View {
    @EnvironmentObject private var library: ProjectLibrary
    @State private var showingCapture = false
    @State private var renaming: ScanProject?
    @State private var projectName = ""
    @State private var discardingDraft: UUID?

    var body: some View {
        NavigationSplitView {
            List {
                if !library.draftIDs.isEmpty {
                    Section("Recover unsaved scans") {
                        Text("Recover the last checkpoint as a saved model. Live scanning cannot resume in its old coordinate frame.").font(.caption)
                        ForEach(library.draftIDs, id: \.self) { id in
                            HStack {
                                Text("Draft \(id.uuidString.prefix(8))")
                                Button("Recover") {
                                    Task {
                                        do { try await library.recoverDraft(id) }
                                        catch { library.errorMessage = "Recovery failed. Draft retained: \(error.localizedDescription)" }
                                    }
                                }.buttonStyle(.bordered)
                                Button("Discard", role: .destructive) { discardingDraft = id }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Section("Projects") {
                    ForEach(library.projects) { project in
                        NavigationLink { SavedModelView(project: project) } label: {
                            VStack(alignment: .leading) {
                                Text(project.name)
                                Text(project.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") { projectName = project.name; renaming = project }
                            Button("Duplicate", systemImage: "doc.on.doc") {
                                Task {
                                    do { try await library.duplicateInBackground(project.id) }
                                    catch { library.errorMessage = error.localizedDescription }
                                }
                            }
                        }
                    }
                    .onDelete(perform: library.delete)
                }
            }
            .navigationTitle("3117 LiDAR SCAN")
            .toolbar { Button("New Scan", systemImage: "plus") { showingCapture = true } }
            .disabled(library.isBusy)
            .overlay { if let operation = library.operation { ProgressView(operation).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        } detail: {
            ContentUnavailableView("Select a project or start a scan", systemImage: "cube.transparent")
        }
        .sheet(isPresented: $showingCapture) { CaptureScreen() }
        .confirmationDialog("Permanently discard this recovery draft?", isPresented: Binding(get: { discardingDraft != nil }, set: { if !$0 { discardingDraft = nil } }), titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) {
                if let id = discardingDraft {
                    do { try library.discardDraft(id) }
                    catch { library.errorMessage = error.localizedDescription }
                }
                discardingDraft = nil
            }
        }
        .sheet(item: $renaming) { project in
            NavigationStack {
                Form { TextField("Project name", text: $projectName) }
                    .navigationTitle("Rename project")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { renaming = nil } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                do { try library.rename(project.id, to: projectName) }
                                catch { library.errorMessage = error.localizedDescription }
                                renaming = nil
                            }.disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
            }.presentationDetents([.medium])
        }
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
    @State private var exportFormat: ScanExportFormat = .ply
    @State private var hasDepthCloud = false
    @State private var hasMesh = false
    @State private var showDepthCloud = true
    @State private var modelSummary = ""
    @State private var loading = false
    @State private var activeProjectID: UUID?
    @State private var measuring = false
    @State private var clearMeasurement = UUID()
    @State private var loadingStage = "Loading model…"
    @State private var selectedPoints: [SIMD3<Float>] = []
    @State private var measurementName = ""
    @State private var namingMeasurement = false
    @State private var showingMeasurements = false
    @State private var measurement = "Tap two surfaces to measure. Drag to orbit; pinch to zoom."

    var body: some View {
        VStack {
            if let scene { MeshSceneView(scene: scene, measuring: measuring, resetID: clearMeasurement, measurement: $measurement, selectedPoints: $selectedPoints) }
            else if loading { ProgressView(loadingStage) }
            else { ContentUnavailableView("Model unavailable", systemImage: "cube") }
            if hasDepthCloud && hasMesh {
                Picker("View layer", selection: $showDepthCloud) {
                    Text("Color point cloud").tag(true)
                    Text("Mesh / measurements").tag(false)
                }.pickerStyle(.segmented).padding(.horizontal)
            }
            if hasDepthCloud && showDepthCloud {
                Text("Depth-derived color points. Switch to mesh for surface measurements.").font(.caption)
            }
            HStack {
                Toggle("Measure surfaces", isOn: $measuring)
                    .disabled(!hasMesh || (hasDepthCloud && showDepthCloud))
                Button("Clear measurement") {
                    clearMeasurement = UUID()
                    selectedPoints = []
                    measurement = "Measurement cleared. Select two surfaces."
                }
            }.padding(.horizontal).disabled(scene == nil)
            Text(measurement).padding()
            Text("A = cyan • B = green • straight-line distance • use Save measurement to retain points").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Save measurement") { measurementName = ""; namingMeasurement = true }
                    .disabled(selectedPoints.count != 2 || library.isBusy)
                Button("Saved measurements") { showingMeasurements = true }.disabled(library.isBusy)
            }
            Text(modelSummary).font(.caption).foregroundStyle(.secondary)
            if let operation = library.operation { ProgressView(operation) }
            Text("Estimated surface distance • validate against site references").font(.caption).foregroundStyle(.secondary)
            Picker("Export format", selection: $exportFormat) {
                ForEach(ScanExportFormat.allCases) { format in Text(format.label).tag(format) }
            }
            Text(hasDepthCloud ? "Metres • Y-up • PLY: depth points + RGB • XYZ: coordinates • OBJ: mesh" : "Metres • Y-up • legacy mesh-vertex PLY/XYZ (no RGB)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Export \(exportFormat.rawValue)") {
                    exportURL = nil
                    let id = project.id
                    let format = exportFormat
                    Task {
                        do {
                            let url = try await library.exportInBackground(project, format: format)
                            if activeProjectID == id { exportURL = url }
                        } catch { if activeProjectID == id { errorMessage = error.localizedDescription } }
                    }
                }.disabled(scene == nil || library.isBusy || (exportFormat == .obj && !hasMesh))
                if let exportURL { ShareLink("Share \(exportURL.pathExtension.uppercased())", item: exportURL) }
            }.padding()
        }
        .navigationTitle(library.projects.first(where: { $0.id == project.id })?.name ?? project.name)
        .task(id: project.id) {
            activeProjectID = project.id
            loading = true
            loadingStage = "Loading model…"
            measuring = false
            clearMeasurement = UUID()
            selectedPoints = []
            showingMeasurements = false
            namingMeasurement = false
            scene = nil
            hasDepthCloud = false
            hasMesh = false
            exportURL = nil
            errorMessage = nil
            modelSummary = ""
            measurement = "Drag to orbit; pinch to zoom. Enable Measure surfaces to select points."
            do {
                let samples = try await library.loadInBackground(project)
                try Task.checkCancellation()
                loadingStage = "Preparing geometry…"
                let worker = Task.detached(priority: .userInitiated) { try PreparedMesh.prepare(samples) }
                let prepared = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                let builtScene = try await buildScene(prepared)
                try Task.checkCancellation()
                hasDepthCloud = samples.contains { $0.depthSource != nil && !$0.vertices.isEmpty }
                hasMesh = samples.contains { !$0.triangles.isEmpty }
                showDepthCloud = hasDepthCloud
                scene = builtScene
                updateVisibleLayer()
                modelSummary = "\(samples.filter { $0.depthSource != nil }.reduce(0) { $0 + $1.vertices.count }) depth points • \(samples.reduce(0) { $0 + $1.triangles.count }) mesh triangles"
            }
            catch is CancellationError { return }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
            if !Task.isCancelled { loading = false }
        }
        .onChange(of: showDepthCloud) { _, _ in
            measuring = false
            selectedPoints = []
            clearMeasurement = UUID()
            measurement = "Drag to orbit; pinch to zoom. Measurements use mesh surfaces."
            updateVisibleLayer()
        }
        .onDisappear { activeProjectID = nil }
        .alert("Name measurement", isPresented: $namingMeasurement) {
            TextField("e.g. Wall width", text: $measurementName)
            Button("Save") {
                guard selectedPoints.count == 2 else { return }
                do {
                    let record = try SavedMeasurement(name: measurementName, a: selectedPoints[0], b: selectedPoints[1])
                    try library.addMeasurement(record, to: project.id)
                    measurement = "Saved: \(record.name) — \(Measurement.display(record.distanceMetres))"
                } catch { errorMessage = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingMeasurements) {
            MeasurementListView(projectID: project.id) { record in
                selectedPoints = [record.a.simd, record.b.simd]
                measuring = false
                measurement = "\(record.name): " + Measurement.display(record.distanceMetres)
                showingMeasurements = false
            }
        }
        .alert("Model operation failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @MainActor
    private func updateVisibleLayer() {
        for node in scene?.rootNode.childNodes ?? [] {
            if node.name == "depthCloud" { node.isHidden = !showDepthCloud }
            if node.name == "mesh" { node.isHidden = hasDepthCloud && showDepthCloud }
        }
    }

    @MainActor
    private func buildScene(_ meshes: [PreparedMesh]) async throws -> SCNScene {
        let scene = SCNScene()
        for (index, mesh) in meshes.enumerated() {
            try Task.checkCancellation()
            loadingStage = "Creating model \(index + 1) / \(meshes.count)…"
            let source = SCNGeometrySource(data: mesh.positions, semantic: .vertex, vectorCount: mesh.vertexCount,
                                           usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
            let isCloud = mesh.triangleCount == 0
            // nil index data means sequential vertices for a point primitive.
            let element = SCNGeometryElement(data: isCloud ? nil : mesh.indices, primitiveType: isCloud ? .point : .triangles,
                                             primitiveCount: isCloud ? mesh.vertexCount : mesh.triangleCount, bytesPerIndex: 4)
            if isCloud {
                element.pointSize = 0.015
                element.minimumPointScreenSpaceRadius = 1
                element.maximumPointScreenSpaceRadius = 4
            }
            var sources = [source]
            if let colors = mesh.colors {
                sources.append(SCNGeometrySource(data: colors, semantic: .color, vectorCount: mesh.vertexCount,
                                                 usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12))
            }
            let geometry = SCNGeometry(sources: sources, elements: [element])
            let material = SCNMaterial()
            material.diffuse.contents = isCloud ? UIColor.white : UIColor.systemOrange
            if isCloud { material.lightingModel = .constant }
            material.isDoubleSided = true
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.name = isCloud ? "depthCloud" : "mesh"
            node.categoryBitMask = isCloud ? 4 : 1
            scene.rootNode.addChildNode(node)
            await Task.yield()
        }
        return scene
    }
}

private struct MeasurementListView: View {
    let projectID: UUID
    let show: (SavedMeasurement) -> Void
    @EnvironmentObject private var library: ProjectLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var reportURL: URL?
    @State private var errorMessage: String?
    private var records: [SavedMeasurement] {
        library.projects.first(where: { $0.id == projectID })?.savedMeasurements ?? []
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Local capture coordinates in metres. Straight-line mesh measurements; verify against site references.").font(.caption)
                    if records.isEmpty { Text("No saved measurements. Select two surfaces, then save with a name.") }
                    ForEach(records) { record in
                        Button { show(record) } label: {
                            VStack(alignment: .leading) {
                                Text(record.name)
                                Text(Measurement.display(record.distanceMetres)).font(.headline)
                                Text(record.createdAt.formatted()).font(.caption)
                                Text("Tap to display endpoints on model").font(.caption)
                            }
                        }.disabled(library.isBusy)
                    }
                }
                Section("Report") {
                    Button("Export CSV") {
                        reportURL = nil
                        Task {
                            do { reportURL = try await library.exportMeasurements(projectID) }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }.disabled(records.isEmpty || library.isBusy)
                    if let reportURL { ShareLink("Share measurement CSV", item: reportURL) }
                    if let operation = library.operation { ProgressView(operation) }
                }
            }
            .navigationTitle("Saved measurements")
            .toolbar { Button("Done") { dismiss() } }
            .alert("Report failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

private struct MeshSceneView: UIViewRepresentable {
    let scene: SCNScene
    let measuring: Bool
    let resetID: UUID
    @Binding var measurement: String
    @Binding var selectedPoints: [SIMD3<Float>]
    func makeCoordinator() -> Coordinator { Coordinator(measurement: $measurement, selectedPoints: $selectedPoints) }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.03, green: 0.06, blue: 0.12, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.scene = scene
        context.coordinator.measuring = measuring
        context.coordinator.resetID = resetID
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        if view.scene !== scene || coordinator.resetID != resetID {
            coordinator.clear()
            view.scene = scene
            coordinator.resetID = resetID
        }
        coordinator.measuring = measuring
        if coordinator.selection.points != selectedPoints {
            coordinator.clear()
            for point in selectedPoints { coordinator.selection.select(point) }
            coordinator.annotate(in: scene)
        }
    }
    final class Coordinator: NSObject {
        var selection = MeasurementSelection()
        var measuring = false
        var resetID: UUID?
        private var annotations: [SCNNode] = []
        var measurement: Binding<String>
        var selectedPoints: Binding<[SIMD3<Float>]>
        init(measurement: Binding<String>, selectedPoints: Binding<[SIMD3<Float>]>) {
            self.measurement = measurement; self.selectedPoints = selectedPoints
        }
        func clear() {
            selection.clear()
            annotations.forEach { $0.removeFromParentNode() }
            annotations.removeAll()
        }
        func annotate(in scene: SCNScene) {
            annotations.forEach { $0.removeFromParentNode() }
            annotations.removeAll()
            for (index, point) in selection.points.enumerated() {
                let sphere = SCNSphere(radius: 0.015)
                let material = SCNMaterial()
                material.diffuse.contents = index == 0 ? UIColor.cyan : UIColor.green
                material.lightingModel = .constant
                sphere.materials = [material]
                let node = SCNNode(geometry: sphere)
                node.position = SCNVector3(point.x, point.y, point.z)
                node.categoryBitMask = 2
                scene.rootNode.addChildNode(node)
                annotations.append(node)
            }
            if selection.points.count == 2 {
                let vertices = selection.points.map { SCNVector3($0.x, $0.y, $0.z) }
                let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [SCNGeometryElement(indices: [Int32(0), Int32(1)], primitiveType: .line)])
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.green
                material.lightingModel = .constant
                geometry.materials = [material]
                let node = SCNNode(geometry: geometry)
                node.categoryBitMask = 2
                scene.rootNode.addChildNode(node)
                annotations.append(node)
            }
        }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard measuring, let view = gesture.view as? SCNView, let scene = view.scene else { return }
            // Annotation nodes use category 2 so they cannot become measurement surfaces.
            guard let hit = view.hitTest(gesture.location(in: view), options: [.categoryBitMask: 1]).first else {
                measurement.wrappedValue = "No surface selected. Tap the mesh."; return
            }
            let p = hit.worldCoordinates
            let point = SIMD3<Float>(p.x, p.y, p.z)
            guard selection.select(point) else { measurement.wrappedValue = "Invalid point. Try another surface."; return }
            selectedPoints.wrappedValue = selection.points
            annotate(in: scene)
            if let distance = selection.distance {
                measurement.wrappedValue = "A → B: " + Measurement.display(distance)
            } else { measurement.wrappedValue = "Point A selected (cyan). Tap point B." }
        }
    }
}
