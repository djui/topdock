// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TopDock",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TopDock",
            path: "Sources/TopDock"
        ),
    ]
)
