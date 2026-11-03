// swift-tools-version:5.10
import PackageDescription

// InlineArray (`[2 of Element]`) needs Swift 6.2.
#if compiler(>=6.2)
let targetAFilesNeedingSwift62: [String] = []
#else
let targetAFilesNeedingSwift62 = ["PublicTypesUsedAsInlineArrayAndPackElements.swift"]
#endif

let package = Package(
    name: "AccessibilityProject",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "app",
            targets: ["MainTarget"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MainTarget",
            dependencies: ["TargetA"]),
        .target(
            name: "ExternalTarget",
            dependencies: []),
        .target(
            name: "TargetA",
            dependencies: ["ExternalTarget"],
            exclude: targetAFilesNeedingSwift62),
        .testTarget(
            name: "TestTarget",
            dependencies: ["MainTarget", "TargetA"])
    ]
)
