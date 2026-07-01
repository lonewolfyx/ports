// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ports",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Ports",
            path: "Sources/Ports",
            resources: [.copy("Resources/app-light.png")]
        )
    ]
)
