// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "comp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MouldCore"),
        .target(name: "MouldRender", dependencies: ["MouldCore"]),
        .executableTarget(name: "comp", dependencies: ["MouldCore", "MouldRender"]),
    ]
)
