// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GHPullCounter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GHPullCounter",
            path: "Sources/GHPullCounter"
        )
    ]
)
