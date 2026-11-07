// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SPMProjectMultiVariant",
    platforms: [.macOS(.v15), .iOS(.v18)],
    targets: [
        .target(name: "Util"),
        .target(name: "Kit", dependencies: ["Util"]),
        .executableTarget(name: "Tool", dependencies: ["Kit"]),
    ]
)
