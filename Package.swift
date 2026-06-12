// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShuttleX",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ShuttleX",
            path: "Sources/ShuttleX"
        )
    ]
)
