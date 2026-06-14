// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ShuttleX",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ShuttleX",
            path: "Sources/ShuttleX"
        ),
        .testTarget(
            name: "ShuttleXTests",
            dependencies: ["ShuttleX"],
            path: "Tests/ShuttleXTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
