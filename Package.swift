// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LiDARScan",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LiDARScan", targets: ["LiDARScan"])],
    targets: [
        .target(name: "LiDARScan", path: "ios", exclude: ["App", "Capture/ScanCoordinator.swift", "Capture/CaptureScreen.swift", "3117LiDARScan.xcodeproj", "Viewer", "Reconstruction", "Export/README.md"]),
        .testTarget(name: "LiDARScanTests", dependencies: ["LiDARScan"], path: "tests")
    ]
)
