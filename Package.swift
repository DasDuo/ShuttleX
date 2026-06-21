// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ShuttleX",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ShuttleX",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
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
