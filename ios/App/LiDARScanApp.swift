import SwiftUI

@main
struct LiDARScanApp: App {
    @StateObject private var library = ProjectLibrary()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(library)
        }
    }
}
