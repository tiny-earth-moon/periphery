import ArgumentParser
import Configuration
import Foundation
import SystemPackage

/// The default values of the options. A fresh configuration on each access: `Configuration` is a mutable class, so a shared
/// instance is not concurrency-safe.
var defaultConfiguration: Configuration {
    Configuration()
}

struct ProjectOptions: ParsableArguments {
    @Flag(help: "Enable guided setup")
    var setup: Bool = defaultConfiguration.guidedSetup

    @Option(help: "Path to the root directory of your project (default: the current directory)", completion: .directory)
    var projectRoot: FilePath?

    @Option(help: "Path to configuration file, relative paths being resolved from '--project-root'. By default outskirts looks for .outskirts.yml (or .periphery.yml) in the project root", completion: .file(extensions: ["yml", "yaml"]))
    var config: FilePath?

    @Option(help: "Path to your project's .xcodeproj or .xcworkspace", completion: .file())
    var project: FilePath?

    @Option(parsing: .upToNextOption, help: "Schemes to build. All targets built by these schemes will be scanned")
    var schemes: [String] = defaultConfiguration.$schemes.defaultValue

    @Option(help: "JSON package manifest path (obtained using `swift package describe --type json` or manually). A relative path is resolved from '--project-root'", completion: .file())
    var jsonPackageManifestPath: FilePath?

    @Option(help: "Project configuration for non-Apple build systems. A relative path is resolved from '--project-root'", completion: .file())
    var genericProjectConfig: FilePath?
}

struct BuildOptions: ParsableArguments {
    @Flag(inversion: .prefixedNo, help: "Clean existing build artifacts before building")
    var cleanBuild: Bool?

    @Flag(inversion: .prefixedNo, help: "Skip the project build step")
    var skipBuild: Bool?

    @Flag(inversion: .prefixedNo, help: "Fail the scan when a source file is newer than its index data, instead of warning")
    var strictIndex: Bool?

    @Flag(inversion: .prefixedNo, help: "Skip schemes validation")
    var skipSchemesValidation: Bool?

    @Flag(inversion: .prefixedNo, help: "Exclude test targets from indexing")
    var excludeTests: Bool?

    @Option(parsing: .upToNextOption, help: "Targets to exclude from indexing")
    var excludeTargets: [String] = defaultConfiguration.$excludeTargets.defaultValue

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from indexing, in addition to the default ones (default: **/*?.build/**/*, **/SourcePackages/checkouts/**)")
    var indexExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Index store paths, relative paths being resolved from '--project-root'. Implies '--skip-build'", completion: .directory)
    var indexStorePath: [FilePath] = defaultConfiguration.$indexStorePath.defaultValue

    @Option(help: "Maximum age in days of unused Xcode build caches before they are evicted at the end of a scan. 0 disables eviction (default: 14)")
    var cacheMaxAgeDays: Int?

    @Option(help: "Maximum total size in gigabytes of the Xcode build caches; the least recently used are evicted at the end of a scan. 0 disables the limit (default: 20)")
    var cacheMaxSizeGb: Int?
}

struct AnalysisOptions: ParsableArguments {
    @Flag(inversion: .prefixedNo, help: "Disable retention of declarations that are unavailable on a platform, or referenced from platform conditional compilation blocks")
    var disablePlatformConditionalRetention: Bool?

    @Flag(inversion: .prefixedNo, help: "Disable identification of redundant public accessibility")
    var disableRedundantPublicAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable identification of redundant public accessibility on the members of public types and extensions")
    var enableRedundantPublicMembers: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable identification of redundant open accessibility and classes or members that could be final")
    var enableOpenFinalAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable identification of empty extensions, which declare no member and no conformance")
    var enableEmptyExtensionAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable identification of access modifiers identical to the default of their enclosing context")
    var enableRedundantAccessLevelAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Report unused generic parameters of types (structs, classes, enums and actors), which are ignored by default as they may be phantom types")
    var reportUnusedTypeParameters: Bool?

    @Flag(inversion: .prefixedNo, help: "Disable identification of unused imports")
    var disableUnusedImportAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable identification of unused imports of system frameworks (experimental)")
    var enableUnusedSystemImports: Bool?

    @Flag(inversion: .prefixedNo, help: "Report superfluous ignore comments (default: enabled)")
    var superfluousIgnoreComments: Bool?

    @Flag(inversion: .prefixedNo, help: "Report optional properties that are read, but never assigned (always nil)")
    var enableUnassignedOptionalAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Report unused colors of Xcode asset catalogs, analyzing the symbols Xcode generates for them in GeneratedAssetSymbols.swift (indexed despite '--index-exclude')")
    var detectUnusedAssetCatalogColors: Bool?

    @Flag(inversion: .prefixedNo, help: "Report unused images of Xcode asset catalogs, analyzing the symbols Xcode generates for them in GeneratedAssetSymbols.swift (indexed despite '--index-exclude')")
    var detectUnusedAssetCatalogImages: Bool?

    @Flag(inversion: .prefixedNo, help: "Report Metal functions (kernel, vertex, fragment, [[visible]], [[stitchable]]) of the project's .metal files that no Swift string literal names, and the literals naming a Metal function that no .metal file declares")
    var detectUnusedMetalFunctions: Bool?
}

struct RetentionOptions: ParsableArguments {
    @Option(parsing: .upToNextOption, help: "Source file globs for which all containing declarations will be retained")
    var retainFiles: [String] = defaultConfiguration.$retainFiles.defaultValue

    @Flag(inversion: .prefixedNo, help: "Retain all public declarations, recommended for framework/library projects")
    var retainPublic: Bool?

    @Option(parsing: .upToNextOption, help: "Modules whose public declarations are retained, for packages that mix libraries with apps or tools. '--no-retain-public' clears the modules of the configuration file")
    var retainPublicModules: [String] = defaultConfiguration.$retainPublicModules.defaultValue

    @Option(parsing: .upToNextOption, help: "Public SPIs (System Programming Interfaces) to check for unused code even when '--retain-public' or '--retain-public-modules' is enabled")
    var noRetainSPI: [String] = defaultConfiguration.$noRetainSPI.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of unused imported modules to retain")
    var retainUnusedImportedModules: [String] = defaultConfiguration.$retainUnusedImportedModules.defaultValue

    @Flag(inversion: .prefixedNo, help: "Retain properties that are assigned, but never used")
    var retainAssignOnlyProperties: Bool?

    @Option(parsing: .upToNextOption, help: "Property types to retain if the property is assigned, but never read")
    var retainAssignOnlyPropertyTypes: [String] = defaultConfiguration.$retainAssignOnlyPropertyTypes.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of external protocols that inherit Encodable. Properties and CodingKey enums of types conforming to these protocols will be retained")
    var externalEncodableProtocols: [String] = defaultConfiguration.$externalEncodableProtocols.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of external protocols that inherit Codable. Properties and CodingKey enums of types conforming to these protocols will be retained")
    var externalCodableProtocols: [String] = defaultConfiguration.$externalCodableProtocols.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of XCTestCase subclasses that reside in external targets")
    var externalTestCaseClasses: [String] = defaultConfiguration.$externalTestCaseClasses.defaultValue

    @Flag(inversion: .prefixedNo, help: "Retain declarations that are exposed to Objective-C implicitly by inheriting NSObject classes, or explicitly with the @objc and @objcMembers attributes")
    var retainObjcAccessible: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain protocols that inherit JSExport, their members, and the members of conforming types that satisfy them")
    var retainJsAccessible: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain declarations that are exposed to Objective-C explicitly with the @objc and @objcMembers attributes")
    var retainObjcAnnotated: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain unused protocol function parameters, even if the parameter is unused in all conforming functions")
    var retainUnusedProtocolFuncParams: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain unused function parameters that have no default value, as removing them would break callers")
    var retainUnusedParametersWithoutDefault: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain SwiftUI previews")
    var retainSwiftUIPreviews: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Codable types (including Encodable and Decodable)")
    var retainCodableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Encodable types only")
    var retainEncodableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Equatable types, including Hashable types")
    var retainEquatableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Hashable types")
    var retainHashableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain stored properties of types whose values are described through reflection, e.g. passed to print, dump, String(describing:) or string interpolation")
    var retainSynthesizedUses: Bool?

    @Option(parsing: .upToNextOption, help: "Retain declarations that have any of the given attributes (without the '@'), optionally limited to declaration kinds with '<attribute>:kind1,kind2', e.g. 'OptionGroup' or 'objc:function.method.instance'")
    var retainAttributes: [String] = defaultConfiguration.$retainAttributes.defaultValue
}

struct ResultsOptions: ParsableArguments {
    @Option(help: "Output format (default: xcode)")
    var format: OutputFormat?

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from the results, optionally limited to result kinds with '<glob>:kind1,kind2'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to include in the results. This option supersedes '--report-exclude'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportInclude: [String] = defaultConfiguration.$reportInclude.defaultValue

    @Flag(inversion: .prefixedNo, help: "Output result paths relative to the project root, or to '--relative-to'")
    var relativeResults: Bool?

    @Option(help: "Directory that result paths are relative to when '--relative-results' is in effect, e.g. $GITHUB_WORKSPACE or $CI_PROJECT_DIR in a monorepo. A relative path is resolved from '--project-root' (default: the project root)", completion: .directory)
    var relativeTo: FilePath?

    @Option(help: "Report only the results in files that changed since this git ref (committed since the merge base with HEAD, uncommitted or untracked), e.g. origin/main. The whole project is still analysed")
    var changedSince: String?

    @Flag(inversion: .prefixedNo, help: "With '--changed-since', report only the results on changed lines. Requires '--changed-since'")
    var changedLines: Bool?

    @Flag(inversion: .prefixedNo, help: "Exit with non-zero status if any unused code is found")
    var strict: Bool?

    @Option(help: "File path where formatted results are written. A relative path is resolved from '--project-root'.", completion: .file())
    var writeResults: FilePath?

    @Flag(help: "Do not print the results to stdout. Requires '--write-results'")
    var skipStdoutResults: Bool = defaultConfiguration.$skipStdoutResults.defaultValue

    @Option(help: "Explain why a declaration is reported, used or retained. Accepts a name (e.g. 'draw()' or 'Beta.draw()'), a USR or a 'file:line' location; repeat the option to explain several")
    var explain: [String] = []
}

struct BaselineOptions: ParsableArguments {
    @Option(help: "Baseline file path used to filter results. A relative path is resolved from '--project-root'", completion: .file())
    var baseline: FilePath?

    @Option(help: "Baseline file path where results are written, in a readable format that lists the kind, name and file of each entry. Entries of the baseline given to '--baseline' are kept. Pass the same path to '--baseline' in subsequent scans to exclude the results recorded in the baseline. A relative path is resolved from '--project-root'.", completion: .file())
    var writeBaseline: FilePath?

    @Flag(inversion: .prefixedNo, help: "Rewrite the file given to '--baseline' keeping only the entries that still match a result. Requires '--baseline'")
    var pruneBaseline: Bool?

    @Flag(inversion: .prefixedNo, help: "Exit with non-zero status (1, like '--strict') if the baseline holds entries that no longer match any result. Requires '--baseline'. Not applied when '--prune-baseline' removes the entries")
    var strictBaseline: Bool?
}

struct LocalizedStringOptions: ParsableArguments {
    @Flag(inversion: .prefixedNo, help: "Disable identification of unused localized strings from String Catalogs (xcstrings)")
    var disableUnusedLocalizedStringAnalysis: Bool?

    @Option(parsing: .upToNextOption, help: "String Catalog (xcstrings) file globs to exclude from unused localized string analysis (default: **/InfoPlist.xcstrings, **/AppShortcuts.xcstrings)")
    var localizedStringCatalogExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Localized string key patterns (globs, or regular expressions between slashes) of keys used dynamically, retained from String Catalogs (xcstrings)")
    var localizedStringKeyPatterns: [String] = defaultConfiguration.$localizedStringKeyPatterns.defaultValue

    @Flag(inversion: .prefixedNo, help: "Retain localized string keys equal to any string literal of the source, whatever its type or position")
    var localizedStringKeyLiteralMatch: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain every String Catalog key that a localized string key built at runtime without a literal prefix may look up")
    var retainRuntimeLocalizedKeys: Bool?
}

struct MiscellaneousOptions: ParsableArguments {
    @Flag(inversion: .prefixedNo, help: "Disable checking for updates")
    var disableUpdateCheck: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable verbose logging")
    var verbose: Bool?

    @Flag(inversion: .prefixedNo, help: "Only output results")
    var quiet: Bool?

    @Option(help: "Colored output mode (default: auto)")
    var color: ColorOption?

    @Flag(name: .customLong("no-color"), help: .hidden)
    var noColor: Bool = false
}
