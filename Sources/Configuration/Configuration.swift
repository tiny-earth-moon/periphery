import Extensions
import FilenameMatcher
import Foundation
import Shared
import SystemPackage

public final class Configuration {
    public static let defaultConfigurationFile = FilePath(".outskirts.yml")
    /// Looked up in this order, the first existing file wins; `.periphery.*` is kept for existing projects.
    public static let configurationFileNames = [".outskirts.yml", ".outskirts.yaml", ".periphery.yml", ".periphery.yaml"]

    public init() {}

    @Setting(key: "project", description: "Path to the .xcodeproj or .xcworkspace.", defaultValue: nil, convert: SettingConverter.filePath)
    public var project: FilePath?

    @Setting(key: "format", description: "Output format of the results.", defaultValue: .default)
    public var outputFormat: OutputFormat

    @Setting(key: "schemes", description: "Schemes to build; every target they build is scanned.", defaultValue: [])
    public var schemes: [String]

    @Setting(key: "exclude_tests", description: "Exclude test targets from indexing.", defaultValue: false)
    public var excludeTests: Bool

    @Setting(key: "exclude_targets", description: "Targets to exclude from indexing.", defaultValue: [])
    public var excludeTargets: [String]

    @Setting(key: "index_exclude", description: "Source file globs to leave out of indexing, added to the default ones.", defaultValue: ["**/*?.build/**/*", "**/SourcePackages/checkouts/**"], requireDefaultValues: true)
    public var indexExclude: [String]

    @Setting(key: "report_exclude", description: "Source file globs to leave out of the results, optionally per result kind with '<glob>:kind1,kind2' or {path, kinds}; the files are still indexed.", defaultValue: [], convert: SettingConverter.reportExclude)
    public var reportExclude: [ReportExcludeEntry]

    @Setting(key: "report_include", description: "Source file globs to keep in the results; supersedes report_exclude; the other files are still indexed.", defaultValue: [])
    public var reportInclude: [String]

    @Setting(key: "build_arguments", description: "Arguments passed to the underlying build tool (swift build or xcodebuild).", defaultValue: [])
    public var buildArguments: [String]

    @Setting(key: "xcode_list_arguments", description: "Extra arguments for the 'xcodebuild -list' call that lists schemes (guided setup).", defaultValue: [])
    public var xcodeListArguments: [String]

    @Setting(key: "retain_assign_only_property_types", description: "Property types to retain when assigned but never read.", defaultValue: [])
    public var retainAssignOnlyPropertyTypes: [String]

    @Setting(key: "enable_unassigned_optional_analysis", description: "Find optional properties that are read but never assigned (always nil).", defaultValue: false)
    public var enableUnassignedOptionalAnalysis: Bool

    @Setting(key: "enable_unconstructed_enum_case_analysis", description: "Find enum cases that are only matched in patterns and never constructed.", defaultValue: false)
    public var enableUnconstructedEnumCaseAnalysis: Bool

    @Setting(key: "external_encodable_protocols", description: "External protocols that inherit Encodable; the properties and CodingKey enums of conforming types are retained.", defaultValue: [])
    public var externalEncodableProtocols: [String]

    @Setting(key: "external_codable_protocols", description: "External protocols that inherit Codable; the properties and CodingKey enums of conforming types are retained.", defaultValue: [])
    public var externalCodableProtocols: [String]

    @Setting(key: "external_test_case_classes", description: "XCTestCase subclasses that live in external targets.", defaultValue: [])
    public var externalTestCaseClasses: [String]

    @Setting(key: "retain_objc_accessible", description: "Retain declarations exposed to Objective-C, implicitly (NSObject subclasses) or with @objc / @objcMembers.", defaultValue: false)
    public var retainObjcAccessible: Bool

    @Setting(key: "retain_js_accessible", description: "Retain protocols that inherit JSExport, their members and the members of conforming types that satisfy them.", defaultValue: false)
    public var retainJsAccessible: Bool

    @Setting(key: "retain_objc_annotated", description: "Retain declarations exposed to Objective-C with @objc / @objcMembers only.", defaultValue: false)
    public var retainObjcAnnotated: Bool

    @Setting(key: "retain_files", description: "Source file globs for which all containing declarations are retained.", defaultValue: [])
    public var retainFiles: [String]

    /// Also takes a list of modules in the configuration file, read as `retain_public_modules`.
    @Setting(key: "retain_public", description: "Retain all public declarations, recommended for framework and library projects. A list of modules is read as retain_public_modules.", defaultValue: false, kind: .boolOrStringList, convert: SettingConverter.bool)
    public var retainPublic: Bool

    @Setting(key: "retain_public_modules", description: "Modules whose public declarations are retained, for packages that mix libraries with apps or tools.", defaultValue: [])
    public var retainPublicModules: [String]

    @Setting(key: "no_retain_spi", description: "Public SPIs to analyze even when retain_public or retain_public_modules is enabled.", defaultValue: [])
    public var noRetainSPI: [String]

    @Setting(key: "retain_assign_only_properties", description: "Retain properties that are assigned but never read.", defaultValue: false)
    public var retainAssignOnlyProperties: Bool

    @Setting(key: "retain_unused_protocol_func_params", description: "Retain unused protocol function parameters, even if unused in all conforming functions.", defaultValue: false)
    public var retainUnusedProtocolFuncParams: Bool

    @Setting(key: "retain_unused_parameters_without_default", description: "Retain unused function parameters that have no default value.", defaultValue: false)
    public var retainUnusedParametersWithoutDefault: Bool

    @Setting(key: "retain_swift_ui_previews", description: "Retain SwiftUI previews.", defaultValue: false)
    public var retainSwiftUIPreviews: Bool

    @Setting(key: "disable_redundant_public_analysis", description: "Disable identification of redundant public accessibility.", defaultValue: false)
    public var disableRedundantPublicAnalysis: Bool

    @Setting(key: "enable_redundant_public_members", description: "Also find redundant public accessibility on the members of public types and extensions.", defaultValue: false)
    public var enableRedundantPublicMembers: Bool

    @Setting(key: "enable_open_final_analysis", description: "Find redundant open accessibility and classes or members that could be final.", defaultValue: false)
    public var enableOpenFinalAnalysis: Bool

    @Setting(key: "enable_empty_extension_analysis", description: "Find extensions that declare no member and no conformance.", defaultValue: false)
    public var enableEmptyExtensionAnalysis: Bool

    @Setting(key: "enable_redundant_access_level_analysis", description: "Find access modifiers identical to the default of their enclosing context.", defaultValue: false)
    public var enableRedundantAccessLevelAnalysis: Bool

    @Setting(key: "report_unused_type_parameters", description: "Also report unused generic parameters of types, ignored by default as they may be phantom types.", defaultValue: false)
    public var reportUnusedTypeParameters: Bool

    @Setting(key: "disable_platform_conditional_retention", description: "Do not retain declarations unavailable on a platform or referenced from platform conditional compilation blocks.", defaultValue: false)
    public var disablePlatformConditionalRetention: Bool

    @Setting(key: "disable_unused_import_analysis", description: "Turn off the analysis of unused imports.", defaultValue: false)
    public var disableUnusedImportAnalysis: Bool

    @Setting(key: "enable_unused_system_imports", description: "Also analyze imports of system frameworks (experimental).", defaultValue: false)
    public var enableUnusedSystemImports: Bool

    @Setting(key: "disable_unused_localized_string_analysis", description: "Turn off the analysis of unused String Catalog (xcstrings) keys.", defaultValue: false)
    public var disableUnusedLocalizedStringAnalysis: Bool

    @Setting(key: "localized_string_catalog_exclude", description: "String Catalog globs left out of the localized strings analysis.", defaultValue: ["**/InfoPlist.xcstrings", "**/AppShortcuts.xcstrings"])
    public var localizedStringCatalogExclude: [String]

    @Setting(key: "localized_string_key_patterns", description: "Key patterns (globs, or regular expressions between slashes) of keys used dynamically, retained from String Catalogs.", defaultValue: [])
    public var localizedStringKeyPatterns: [String]

    @Setting(key: "localized_string_key_literal_match", description: "Retain localized string keys equal to any string literal of the source.", defaultValue: false)
    public var localizedStringKeyLiteralMatch: Bool

    @Setting(key: "retain_runtime_localized_keys", description: "Retain every key that a localized string key built at runtime without a literal prefix may look up.", defaultValue: false)
    public var retainRuntimeLocalizedKeys: Bool

    @Setting(key: "superfluous_ignore_comments", description: "Report ignore comments that ignore nothing.", defaultValue: true)
    public var superfluousIgnoreComments: Bool

    @Setting(key: "retain_unused_imported_modules", description: "Names of imported modules to retain even when unused.", defaultValue: [])
    public var retainUnusedImportedModules: [String]

    @Setting(key: "retain_codable_properties", description: "Retain properties on Codable types (including Encodable and Decodable).", defaultValue: false)
    public var retainCodableProperties: Bool

    @Setting(key: "retain_encodable_properties", description: "Retain properties on Encodable types only.", defaultValue: false)
    public var retainEncodableProperties: Bool

    @Setting(key: "retain_equatable_properties", description: "Retain properties on Equatable types, including Hashable types.", defaultValue: false)
    public var retainEquatableProperties: Bool

    @Setting(key: "retain_hashable_properties", description: "Retain properties on Hashable types.", defaultValue: false)
    public var retainHashableProperties: Bool

    @Setting(key: "verbose", description: "Enable verbose logging.", defaultValue: false)
    public var verbose: Bool

    @Setting(key: "quiet", description: "Print only the results.", defaultValue: false)
    public var quiet: Bool

    @Setting(key: "color", description: "Colored output mode.", defaultValue: .default)
    public var color: ColorOption

    @Setting(key: "disable_update_check", description: "Do not check for a new version.", defaultValue: false)
    public var disableUpdateCheck: Bool

    @Setting(key: "strict", description: "Exit with status 1 if any result is reported.", defaultValue: false)
    public var strict: Bool

    @Setting(key: "index_store_path", description: "Index store paths, relative to the project root; implies skip_build.", defaultValue: [], convert: SettingConverter.filePathList)
    public var indexStorePath: [FilePath]

    @Setting(key: "skip_build", description: "Skip the project build step.", defaultValue: false)
    public var skipBuild: Bool

    @Setting(key: "skip_schemes_validation", description: "Do not check that the schemes exist.", defaultValue: false)
    public var skipSchemesValidation: Bool

    @Setting(key: "clean_build", description: "Remove existing build artifacts before building.", defaultValue: false)
    public var cleanBuild: Bool

    @Setting(key: "strict_index", description: "Fail the scan when a source file is newer than its index data, instead of warning.", defaultValue: false)
    public var strictIndex: Bool

    @Setting(key: "relative_results", description: "Report paths relative to the project root, or to relative_results_base.", defaultValue: false)
    public var relativeResults: Bool

    @Setting(key: "relative_results_base", description: "Directory the result paths are relative to when relative_results is in effect (command line: --relative-to).", defaultValue: nil, convert: SettingConverter.filePath)
    public var relativeResultsBase: FilePath?

    @Setting(key: "changed_since", description: "Report only the results in files that changed since this git ref: committed since its merge base with HEAD, uncommitted or untracked (command line: --changed-since). The whole project is still analysed.", defaultValue: nil, convert: SettingConverter.optionalString)
    public var changedSince: String?

    @Setting(key: "changed_lines", description: "With changed_since, report only the results on changed lines.", defaultValue: false)
    public var changedLines: Bool

    @Setting(key: "json_package_manifest_path", description: "Package manifest as JSON (from 'swift package describe --type json', or written by hand).", defaultValue: nil, convert: SettingConverter.filePath)
    public var jsonPackageManifestPath: FilePath?

    @Setting(key: "cache_max_age_days", description: "Age in days after which unused Xcode build caches are evicted at the end of a scan; 0 disables the age rule. Caches of projects that no longer exist are always evicted.", defaultValue: 14)
    public var cacheMaxAgeDays: Int

    @Setting(key: "cache_max_size_gb", description: "Total size in gigabytes above which the least recently used Xcode build caches are evicted at the end of a scan; 0 disables the limit.", defaultValue: 20)
    public var cacheMaxSizeGB: Int

    @Setting(key: "baseline", description: "Baseline file whose entries are hidden from the results.", defaultValue: nil, convert: SettingConverter.filePath)
    public var baseline: FilePath?

    @Setting(key: "write_baseline", description: "Write the results to a baseline file, keeping the entries of baseline.", defaultValue: nil, convert: SettingConverter.filePath)
    public var writeBaseline: FilePath?

    @Setting(key: "prune_baseline", description: "Rewrite the baseline file keeping only the entries that still match a result; requires baseline.", defaultValue: false)
    public var pruneBaseline: Bool

    @Setting(key: "strict_baseline", description: "Exit with status 1 if the baseline holds entries that no longer match; requires baseline.", defaultValue: false)
    public var strictBaseline: Bool

    @Setting(key: "write_results", description: "Also write the formatted results to a file.", defaultValue: nil, convert: SettingConverter.filePath)
    public var writeResults: FilePath?

    @Setting(key: "skip_stdout_results", description: "Do not print the results to stdout; requires write_results.", defaultValue: false)
    public var skipStdoutResults: Bool

    @Setting(key: "generic_project_config", description: "Project configuration file for other build systems.", defaultValue: nil, convert: SettingConverter.filePath)
    public var genericProjectConfig: FilePath?

    @Setting(key: "retain_synthesized_uses", description: "Retain stored properties of types whose values are described through reflection (print, dump, String(describing:), interpolation).", defaultValue: false)
    public var retainSynthesizedUses: Bool

    @Setting(key: "retain_attributes", description: "Retain declarations that have one of the given attributes (without the @), optionally per declaration kind with '<attribute>:kind1,kind2'.", defaultValue: [])
    public var retainAttributes: [String]

    @Setting(key: "detect_unused_asset_catalog_colors", description: "Find unused colors of Xcode asset catalogs.", defaultValue: false)
    public var detectUnusedAssetCatalogColors: Bool

    @Setting(key: "detect_unused_asset_catalog_images", description: "Find unused images of Xcode asset catalogs.", defaultValue: false)
    public var detectUnusedAssetCatalogImages: Bool

    @Setting(key: "detect_unused_metal_functions", description: "Find Metal functions that no Swift string literal names, and literals naming a Metal function that no .metal file declares.", defaultValue: false)
    public var detectUnusedMetalFunctions: Bool

    // Non user facing.
    public var guidedSetup: Bool = false
    public var projectRoot: FilePath = .init()

    /// The declarations to explain (`--explain`, command line only): names, USRs or `file:line` locations.
    public var explain: [String] = []

    /// `--summary` or `--no-summary` (command line only), nil when neither is given: the summary is then printed with
    /// the `xcode` format and left out of the `json` format.
    public var summary: Bool?

    public var hasNonDefaultValues: Bool {
        settings.contains(where: \.hasNonDefaultValue)
    }

    // MARK: - Helpers

    /// Applies a value given on the command line, which takes precedence over the configuration file whatever it is,
    /// the default included. A nil value was not given and leaves the setting untouched.
    public func apply<T: Equatable>(_ path: KeyPath<Configuration, Setting<T>>, _ value: T?) {
        guard let value else { return }

        self[keyPath: path].wrappedValue = value
    }

    public func apply<T: Equatable>(_ path: KeyPath<Configuration, Setting<T?>>, _ value: T?) {
        guard let value else { return }

        self[keyPath: path].wrappedValue = value
    }

    /// Whether some public declarations are retained, by `retain_public` or `retain_public_modules`.
    public var retainsPublicDeclarations: Bool {
        retainPublic || !retainPublicModules.isEmpty
    }

    /// Whether the public declarations of a file compiled into the given modules are retained.
    public func retainsPublicDeclarations(inModules modules: Set<String>) -> Bool {
        retainPublic || retainPublicModules.contains(where: modules.contains)
    }

    public func buildFilenameMatchers() {
        indexExcludeMatchers = buildFilenameMatchers(with: indexExclude)
        retainFilesMatchers = buildFilenameMatchers(with: retainFiles)
        reportIncludeMatchers = buildFilenameMatchers(with: reportInclude)
        localizedStringCatalogExcludeMatchers = buildFilenameMatchers(with: localizedStringCatalogExclude)
    }

    public var indexExcludeMatchers: [FilenameMatcher] = []
    public var retainFilesMatchers: [FilenameMatcher] = []
    public var reportIncludeMatchers: [FilenameMatcher] = []
    public var localizedStringCatalogExcludeMatchers: [FilenameMatcher] = []

    /// Name of the Swift file Xcode generates for the symbols of asset catalog resources.
    public static let generatedAssetSymbolsFileName = "GeneratedAssetSymbols.swift"
    public static let generatedStringSymbolsFileNamePrefix = "GeneratedStringSymbols_"

    /// Whether any kind of unused asset catalog symbol is detected.
    public var detectsUnusedAssetCatalogSymbols: Bool {
        detectUnusedAssetCatalogColors || detectUnusedAssetCatalogImages
    }

    /// Whether the file holds generated asset catalog symbols that must be analyzed, which is only the case when
    /// unused asset catalog symbols are detected.
    public func isAnalyzedGeneratedAssetSymbolsFile(_ path: FilePath) -> Bool {
        detectsUnusedAssetCatalogSymbols && path.lastComponent?.string == Self.generatedAssetSymbolsFileName
    }

    /// Whether the file holds the String Catalog symbols Xcode generates (`GeneratedStringSymbols_<Table>.swift`)
    /// and must be read, which is only the case when unused localized strings are detected.
    public func isAnalyzedGeneratedStringSymbolsFile(_ path: FilePath) -> Bool {
        guard !disableUnusedLocalizedStringAnalysis, path.extension == "swift",
              let name = path.lastComponent?.string
        else { return false }

        return name.hasPrefix(Self.generatedStringSymbolsFileNamePrefix)
    }

    /// Whether the file is excluded from indexing by `index_exclude`. Generated asset and String Catalog symbols files
    /// are an exception when their analysis is enabled, as they live in excluded build directories.
    public func isIndexExcluded(_ path: FilePath) -> Bool {
        guard !isAnalyzedGeneratedAssetSymbolsFile(path), !isAnalyzedGeneratedStringSymbolsFile(path) else { return false }

        return indexExcludeMatchers.anyMatch(filename: path.string)
    }

    // MARK: - Private

    lazy var settings: [any AbstractSetting] = [
        $project, $schemes, $excludeTargets, $excludeTests, $indexExclude, $reportExclude, $reportInclude, $outputFormat,
        $retainPublic, $retainPublicModules, $noRetainSPI, $retainFiles, $retainAssignOnlyProperties, $retainAssignOnlyPropertyTypes, $enableUnassignedOptionalAnalysis, $enableUnconstructedEnumCaseAnalysis, $retainObjcAccessible,
        $retainJsAccessible, $retainObjcAnnotated, $retainUnusedProtocolFuncParams, $retainUnusedParametersWithoutDefault, $retainSwiftUIPreviews, $disableRedundantPublicAnalysis, $enableRedundantPublicMembers, $enableOpenFinalAnalysis, $enableEmptyExtensionAnalysis, $enableRedundantAccessLevelAnalysis, $reportUnusedTypeParameters,
        $disablePlatformConditionalRetention, $disableUnusedImportAnalysis, $enableUnusedSystemImports, $disableUnusedLocalizedStringAnalysis, $localizedStringCatalogExclude, $localizedStringKeyPatterns, $localizedStringKeyLiteralMatch, $retainRuntimeLocalizedKeys, $superfluousIgnoreComments, $retainUnusedImportedModules,
        $externalEncodableProtocols, $externalCodableProtocols, $externalTestCaseClasses, $verbose, $quiet, $color,
        $disableUpdateCheck, $strict, $indexStorePath,
        $skipBuild, $skipSchemesValidation, $cleanBuild, $strictIndex, $cacheMaxAgeDays, $cacheMaxSizeGB, $buildArguments, $xcodeListArguments, $relativeResults, $relativeResultsBase, $changedSince, $changedLines,
        $jsonPackageManifestPath, $retainCodableProperties, $retainEncodableProperties, $retainEquatableProperties,
        $retainHashableProperties, $baseline, $writeBaseline, $pruneBaseline, $strictBaseline,
        $writeResults, $skipStdoutResults, $genericProjectConfig,
        $retainSynthesizedUses, $retainAttributes, $detectUnusedAssetCatalogColors, $detectUnusedAssetCatalogImages,
        $detectUnusedMetalFunctions,
    ]

    public func buildFilenameMatchers(with patterns: [String]) -> [FilenameMatcher] {
        // TODO: respect filesystem case sensitivity.
        let pwd = FilePath.current.string
        return patterns.map { FilenameMatcher(relativePattern: $0, to: pwd, caseSensitive: false) }
    }
}
