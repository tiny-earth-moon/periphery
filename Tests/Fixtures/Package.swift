// swift-tools-version:5.10
import PackageDescription

// Fixtures that need SwiftUI, SwiftData or the Objective-C runtime; their tests are macOS-only.
#if os(Linux)
let retentionFixturesExcludedOnLinux = [
    "AssetCatalogs",
    "testDetectsUnusedAssetCatalogColors.swift",
    "testObjcOptionalProtocolMembersInExtension.swift",
    "testRetainsMacroStatePropertyInitializedViaBackingStorage.swift",
    "testRetainsMacroStatePropertyReferencedOnlyViaBackingStorage.swift",
    "testRetainsMacroStatePropertyReferencedOnlyViaProjectedValue.swift",
    "testRetainsPropertyWrapperPropertiesReferencedOnlyViaProjectedValue.swift",
    "testRetainsSoleInitializerOfMacroModelClass.swift",
    "testRetainsViewExtensionMembersCalledInPostfixPlatformConditionalBlock.swift",
]
let knownSwiftBugsFixturesExcludedOnLinux = ["testOptionalObjcMethodInSubclassIsRelated.swift"]
#else
let retentionFixturesExcludedOnLinux: [String] = []
let knownSwiftBugsFixturesExcludedOnLinux: [String] = []
#endif

// `@c`, `@section` and `@used` need Swift 6.2; their tests are macOS-only.
#if compiler(>=6.2)
let linkageFixturesNeedingSwift62: [String] = []
#else
let linkageFixturesNeedingSwift62 = [
    "testRetainsCFunction.swift",
    "testRetainsSectionGlobal.swift",
    "testRetainsUsedGlobal.swift",
]
#endif

// `@objc` enums need the Objective-C runtime; their test is macOS-only.
#if os(Linux)
let unconstructedEnumCaseFixturesExcludedOnLinux = ["testObjcEnumsAreNotReported.swift"]
#else
let unconstructedEnumCaseFixturesExcludedOnLinux: [String] = []
#endif

var targets: [PackageDescription.Target] = [
    .target(
        name: "ExternalModuleFixtures"
    ),
    .target(
        name: "UnusedModuleFixtures"
    ),
    .target(
        name: "CrossModuleRetentionFixtures",
        dependencies: [
            .target(name: "CrossModuleRetentionSupportFixtures")
        ]
    ),
    .target(
        name: "CrossModuleRetentionSupportFixtures"
    ),
    .target(
        name: "UnusedImportFixtureA",
        path: "Sources/UnusedImportFixtures/A"
    ),
    .target(
        name: "UnusedImportFixtureB",
        dependencies: [
            .target(name: "UnusedImportFixtureA")
        ],
        path: "Sources/UnusedImportFixtures/B"
    ),
    .target(
        name: "UnusedImportFixtureC",
        dependencies: [
            .target(name: "UnusedImportFixtureA")
        ],
        path: "Sources/UnusedImportFixtures/C"
    ),
    .target(
        name: "UnusedImportFixtureD",
        dependencies: [
            .target(name: "UnusedImportFixtureA"),
            .target(name: "UnusedImportFixtureB"),
            .target(name: "UnusedImportFixtureC")
        ],
        path: "Sources/UnusedImportFixtures/D"
    ),
    .target(
        name: "UnusedSystemImportFixtures"
    ),
    .target(
        name: "UnusedImportDistributedFixtures"
    ),
    .target(
        name: "UnusedImportScopedSupportFixtures",
        path: "Sources/UnusedImportScopedFixtures/Support"
    ),
    .target(
        name: "UnusedImportScopedClientFixtures",
        dependencies: [
            .target(name: "UnusedImportScopedSupportFixtures")
        ],
        path: "Sources/UnusedImportScopedFixtures/Client"
    ),
    .target(
        name: "UnusedImportPlatformSupportFixtures",
        path: "Sources/UnusedImportPlatformFixtures/Support"
    ),
    .target(
        name: "UnusedImportPlatformClientFixtures",
        dependencies: [
            .target(name: "UnusedImportPlatformSupportFixtures")
        ],
        path: "Sources/UnusedImportPlatformFixtures/Client"
    ),
    .target(
        name: "UnusedImportPlatformSystemFixtures",
        path: "Sources/UnusedImportPlatformFixtures/System"
    ),
    .target(
        name: "RetentionFixtures",
        dependencies: [
            .target(name: "ExternalModuleFixtures"),
            .target(name: "UnusedModuleFixtures")
        ],
        exclude: retentionFixturesExcludedOnLinux
    ),
    .target(
        name: "UnusedParameterFixtures",
        swiftSettings: [
            .unsafeFlags(["-suppress-warnings"]) // Suppress warnings from testLocalVariableAssignment
        ]
    ),
    .target(
        name: "KnownSwiftBugsFixtures",
        exclude: knownSwiftBugsFixturesExcludedOnLinux
    ),
    .target(
        name: "UnusedParameterRetentionFixtures"
    ),
    .target(
        name: "TypeSyntaxInspectorFixtures"
    ),
    .target(
        name: "DeclarationVisitorFixtures"
    ),
    .target(
        name: "UnassignedOptionalFixtures"
    ),
    .target(
        name: "LinkageRetentionFixtures",
        exclude: linkageFixturesNeedingSwift62,
        swiftSettings: [
            .unsafeFlags(["-enable-experimental-feature", "Extern"]) // For the @_extern(c) declarations.
        ]
    ),
    .target(
        name: "DynamicCallableRetentionFixtures"
    ),
    .target(
        name: "DynamicCallableSupportFixtures"
    ),
    .target(
        name: "DynamicCallableCrossModuleFixtures",
        dependencies: [
            .target(name: "DynamicCallableSupportFixtures")
        ]
    ),
    .target(
        name: "UnassignedOptionalKeyPathFixtures"
    ),
    .target(
        name: "EnumCaseRetentionFixtures"
    ),
    .target(
        name: "UnconstructedEnumCaseSupportFixtures"
    ),
    .target(
        name: "UnconstructedEnumCaseFixtures",
        dependencies: [
            .target(name: "UnconstructedEnumCaseSupportFixtures")
        ],
        exclude: unconstructedEnumCaseFixturesExcludedOnLinux
    ),
]

#if os(macOS)
targets.append(contentsOf: [
    .target(
        name: "ObjcAccessibleRetentionFixtures"
    ),
    .target(
        name: "ObjcAnnotatedRetentionFixtures"
    ),
    .target(
        name: "AppIntentsRetentionFixtures"
    ),
    .target(
        name: "SwiftUIWidgetRetentionFixtures"
    ),
    .target(
        name: "AppIntentsMetadataRetentionFixtures"
    ),
    .target(
        name: "RetainedAncestorRetentionFixtures"
    ),
    .target(
        name: "UnusedAssetCatalogImageFixtures"
    ),
    // The .metal files are read as plain files, never compiled.
    .target(
        name: "MetalFunctionFixtures",
        exclude: ["Shaders"]
    )
])
#endif

let package = Package(
    name: "Fixtures",
    platforms: [.macOS(.v13)],
    targets: targets,
    swiftLanguageVersions: [.v5]
)
