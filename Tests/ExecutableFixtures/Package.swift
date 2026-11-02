// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ExecutableFixtures",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TopLevelCodeLib"),
        .executableTarget(name: "TopLevelCodeBox"),
        .executableTarget(
            name: "TopLevelCodeCross",
            dependencies: ["TopLevelCodeLib"]
        ),
        .executableTarget(name: "TopLevelCodeScript"),
    ],
    swiftLanguageVersions: [.v5]
)
