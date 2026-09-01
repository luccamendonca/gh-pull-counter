// swift-tools-version: 6.2
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
