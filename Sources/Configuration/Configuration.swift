import Extensions
import FilenameMatcher
import Foundation
import Logger
import Shared
import SystemPackage
import Yams

public final class Configuration {
    public static let defaultConfigurationFile = FilePath(".outskirts.yml")
    /// Looked up in this order, the first existing file wins; `.periphery.*` is kept for existing projects.
    public static let configurationFileNames = [".outskirts.yml", ".outskirts.yaml", ".periphery.yml", ".periphery.yaml"]

    public init() {}

    @Setting(key: "project", defaultValue: nil, convert: SettingConverter.filePath)
    public var project: FilePath?

    @Setting(key: "format", defaultValue: .default)
    public var outputFormat: OutputFormat

    @Setting(key: "schemes", defaultValue: [])
    public var schemes: [String]

    @Setting(key: "exclude_tests", defaultValue: false)
    public var excludeTests: Bool

    @Setting(key: "exclude_targets", defaultValue: [])
    public var excludeTargets: [String]

    @Setting(key: "index_exclude", defaultValue: ["**/*?.build/**/*", "**/SourcePackages/checkouts/**"], requireDefaultValues: true)
    public var indexExclude: [String]

    @Setting(key: "report_exclude", defaultValue: [], convert: SettingConverter.reportExclude)
    public var reportExclude: [ReportExcludeEntry]

    @Setting(key: "report_include", defaultValue: [])
    public var reportInclude: [String]

    @Setting(key: "build_arguments", defaultValue: [])
    public var buildArguments: [String]

    @Setting(key: "xcode_list_arguments", defaultValue: [])
    public var xcodeListArguments: [String]

    @Setting(key: "retain_assign_only_property_types", defaultValue: [])
    public var retainAssignOnlyPropertyTypes: [String]

    @Setting(key: "enable_unassigned_optional_analysis", defaultValue: false)
    public var enableUnassignedOptionalAnalysis: Bool

    @Setting(key: "external_encodable_protocols", defaultValue: [])
    public var externalEncodableProtocols: [String]

    @Setting(key: "external_codable_protocols", defaultValue: [])
    public var externalCodableProtocols: [String]

    @Setting(key: "external_test_case_classes", defaultValue: [])
    public var externalTestCaseClasses: [String]

    @Setting(key: "retain_objc_accessible", defaultValue: false)
    public var retainObjcAccessible: Bool

    @Setting(key: "retain_js_accessible", defaultValue: false)
    public var retainJsAccessible: Bool

    @Setting(key: "retain_objc_annotated", defaultValue: false)
    public var retainObjcAnnotated: Bool

    @Setting(key: "retain_files", defaultValue: [])
    public var retainFiles: [String]

    /// Also takes a list of modules in the configuration file, read as `retain_public_modules`.
    @Setting(key: "retain_public", defaultValue: false, kind: .boolOrStringList, convert: SettingConverter.bool)
    public var retainPublic: Bool

    @Setting(key: "retain_public_modules", defaultValue: [])
    public var retainPublicModules: [String]

    @Setting(key: "no_retain_spi", defaultValue: [])
    public var noRetainSPI: [String]

    @Setting(key: "retain_assign_only_properties", defaultValue: false)
    public var retainAssignOnlyProperties: Bool

    @Setting(key: "retain_unused_protocol_func_params", defaultValue: false)
    public var retainUnusedProtocolFuncParams: Bool

    @Setting(key: "retain_unused_parameters_without_default", defaultValue: false)
    public var retainUnusedParametersWithoutDefault: Bool

    @Setting(key: "retain_swift_ui_previews", defaultValue: false)
    public var retainSwiftUIPreviews: Bool

    @Setting(key: "disable_redundant_public_analysis", defaultValue: false)
    public var disableRedundantPublicAnalysis: Bool

    @Setting(key: "enable_redundant_public_members", defaultValue: false)
    public var enableRedundantPublicMembers: Bool

    @Setting(key: "enable_open_final_analysis", defaultValue: false)
    public var enableOpenFinalAnalysis: Bool

    @Setting(key: "enable_empty_extension_analysis", defaultValue: false)
    public var enableEmptyExtensionAnalysis: Bool

    @Setting(key: "enable_redundant_access_level_analysis", defaultValue: false)
    public var enableRedundantAccessLevelAnalysis: Bool

    @Setting(key: "report_unused_type_parameters", defaultValue: false)
    public var reportUnusedTypeParameters: Bool

    @Setting(key: "disable_platform_conditional_retention", defaultValue: false)
    public var disablePlatformConditionalRetention: Bool

    @Setting(key: "disable_unused_import_analysis", defaultValue: false)
    public var disableUnusedImportAnalysis: Bool

    @Setting(key: "enable_unused_system_imports", defaultValue: false)
    public var enableUnusedSystemImports: Bool

    @Setting(key: "disable_unused_localized_string_analysis", defaultValue: false)
    public var disableUnusedLocalizedStringAnalysis: Bool

    @Setting(key: "localized_string_catalog_exclude", defaultValue: ["**/InfoPlist.xcstrings", "**/AppShortcuts.xcstrings"])
    public var localizedStringCatalogExclude: [String]

    @Setting(key: "localized_string_key_patterns", defaultValue: [])
    public var localizedStringKeyPatterns: [String]

    @Setting(key: "localized_string_key_literal_match", defaultValue: false)
    public var localizedStringKeyLiteralMatch: Bool

    @Setting(key: "retain_runtime_localized_keys", defaultValue: false)
    public var retainRuntimeLocalizedKeys: Bool

    @Setting(key: "superfluous_ignore_comments", defaultValue: true)
    public var superfluousIgnoreComments: Bool

    @Setting(key: "retain_unused_imported_modules", defaultValue: [])
    public var retainUnusedImportedModules: [String]

    @Setting(key: "retain_codable_properties", defaultValue: false)
    public var retainCodableProperties: Bool

    @Setting(key: "retain_encodable_properties", defaultValue: false)
    public var retainEncodableProperties: Bool

    @Setting(key: "retain_equatable_properties", defaultValue: false)
    public var retainEquatableProperties: Bool

    @Setting(key: "retain_hashable_properties", defaultValue: false)
    public var retainHashableProperties: Bool

    @Setting(key: "verbose", defaultValue: false)
    public var verbose: Bool

    @Setting(key: "quiet", defaultValue: false)
    public var quiet: Bool

    @Setting(key: "color", defaultValue: .default)
    public var color: ColorOption

    @Setting(key: "disable_update_check", defaultValue: false)
    public var disableUpdateCheck: Bool

    @Setting(key: "strict", defaultValue: false)
    public var strict: Bool

    @Setting(key: "index_store_path", defaultValue: [], convert: SettingConverter.filePathList)
    public var indexStorePath: [FilePath]

    @Setting(key: "skip_build", defaultValue: false)
    public var skipBuild: Bool

    @Setting(key: "skip_schemes_validation", defaultValue: false)
    public var skipSchemesValidation: Bool

    @Setting(key: "clean_build", defaultValue: false)
    public var cleanBuild: Bool

    @Setting(key: "relative_results", defaultValue: false)
    public var relativeResults: Bool

    @Setting(key: "relative_results_base", defaultValue: nil, convert: SettingConverter.filePath)
    public var relativeResultsBase: FilePath?

    @Setting(key: "changed_since", defaultValue: nil, convert: SettingConverter.optionalString)
    public var changedSince: String?

    @Setting(key: "changed_lines", defaultValue: false)
    public var changedLines: Bool

    @Setting(key: "json_package_manifest_path", defaultValue: nil, convert: SettingConverter.filePath)
    public var jsonPackageManifestPath: FilePath?

    @Setting(key: "cache_max_age_days", defaultValue: 14)
    public var cacheMaxAgeDays: Int

    @Setting(key: "cache_max_size_gb", defaultValue: 20)
    public var cacheMaxSizeGB: Int

    @Setting(key: "baseline", defaultValue: nil, convert: SettingConverter.filePath)
    public var baseline: FilePath?

    @Setting(key: "write_baseline", defaultValue: nil, convert: SettingConverter.filePath)
    public var writeBaseline: FilePath?

    @Setting(key: "prune_baseline", defaultValue: false)
    public var pruneBaseline: Bool

    @Setting(key: "strict_baseline", defaultValue: false)
    public var strictBaseline: Bool

    @Setting(key: "write_results", defaultValue: nil, convert: SettingConverter.filePath)
    public var writeResults: FilePath?

    @Setting(key: "skip_stdout_results", defaultValue: false)
    public var skipStdoutResults: Bool

    @Setting(key: "generic_project_config", defaultValue: nil, convert: SettingConverter.filePath)
    public var genericProjectConfig: FilePath?

    @Setting(key: "retain_synthesized_uses", defaultValue: false)
    public var retainSynthesizedUses: Bool

    @Setting(key: "retain_attributes", defaultValue: [])
    public var retainAttributes: [String]

    @Setting(key: "detect_unused_asset_catalog_colors", defaultValue: false)
    public var detectUnusedAssetCatalogColors: Bool

    @Setting(key: "detect_unused_asset_catalog_images", defaultValue: false)
    public var detectUnusedAssetCatalogImages: Bool

    @Setting(key: "detect_unused_metal_functions", defaultValue: false)
    public var detectUnusedMetalFunctions: Bool

    // Non user facing.
    public var guidedSetup: Bool = false
    public var projectRoot: FilePath = .init()

    public var hasNonDefaultValues: Bool {
        settings.contains(where: \.hasNonDefaultValue)
    }

    public func asYaml() throws -> String {
        var config: [String: Any?] = [:]

        for setting in settings where setting.hasNonDefaultValue {
            config[setting.key] = setting.wrappedValue
        }

        return try Yams.dump(object: config)
    }

    public func save(to path: FilePath = defaultConfigurationFile) throws {
        let data = try (Self.schemaComment + "\n" + asYaml()).data(using: .utf8)
        FileManager.default.createFile(atPath: path.string, contents: data)
    }

    /// Loads the configuration file. A value that is not valid for its setting, and a key that is not a setting, are
    /// reported to `warn` and ignored, an unreadable file or a document that is not a mapping is an error.
    public func load(from path: FilePath?, warn: ((String) -> Void)? = nil) throws {
        guard let path = try configurationPath(withUserProvided: path) else { return }

        let encodedYAML = try String(contentsOf: path.url, encoding: .utf8)
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)
        let warn = warn ?? { logger.warn($0) }

        // An empty document is an empty configuration.
        guard let document = try Yams.load(yaml: encodedYAML) else { return }
        guard let yaml = document as? [AnyHashable: Any] else {
            throw PeripheryError.usageError("\(path.string): the configuration must be a mapping of keys to values, got \(SettingValueError.describe(document))")
        }

        let entries = yaml.map { (key: "\($0.key.base)", value: $0.value, isString: $0.key.base is String) }.sorted { $0.key < $1.key }

        if let key = entries.map(\.key).first(where: Self.isRemovedBazelKey) {
            throw PeripheryError.removedBazelOption("'\(key)' in \(path.string)")
        }

        for (key, value, isString) in entries {
            if isString, key == $retainPublic.key, value is [Any] {
                if let message = $retainPublicModules.assign(value, reportedKey: key) {
                    warn("\(path.string): \(message)")
                }
            } else if isString, let setting = settings.first(where: { key == $0.key }) {
                if let message = setting.assign(value) {
                    warn("\(path.string): \(message)")
                }
            } else if isString, let suggestion = closestSettingKey(to: key) {
                warn("\(path.string): invalid key '\(key)' (did you mean '\(suggestion)'?)")
            } else {
                warn("\(path.string): invalid key '\(key)'")
            }
        }
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

    /// Keys of the Bazel mode, removed in 3.13.0, which are rejected instead of being reported as invalid keys.
    /// The setting key that a misspelt key most likely stands for, if any is close enough.
    private func closestSettingKey(to key: String) -> String? {
        let normalized = key.lowercased().replacingOccurrences(of: "-", with: "_")
        let candidates = settings.map(\.key).sorted()

        if let exact = candidates.first(where: { $0 == normalized }) {
            return exact
        }

        let maxDistance = min(3, max(1, key.count / 4))
        let ranked = candidates.map { (key: $0, distance: Self.editDistance(normalized, $0)) }

        return ranked.filter { $0.distance <= maxDistance }.min { $0.distance < $1.distance }?.key
    }

    /// The Levenshtein distance between two strings.
    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        var previous = Array(0 ... rhs.count)

        for (i, l) in lhs.enumerated() {
            var current = [i + 1]

            for (j, r) in rhs.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (l == r ? 0 : 1)))
            }

            previous = current
        }

        return previous[rhs.count]
    }

    private static func isRemovedBazelKey(_ key: String) -> Bool {
        key == "bazel" || key.hasPrefix("bazel_")
    }

    lazy var settings: [any AbstractSetting] = [
        $project, $schemes, $excludeTargets, $excludeTests, $indexExclude, $reportExclude, $reportInclude, $outputFormat,
        $retainPublic, $retainPublicModules, $noRetainSPI, $retainFiles, $retainAssignOnlyProperties, $retainAssignOnlyPropertyTypes, $enableUnassignedOptionalAnalysis, $retainObjcAccessible,
        $retainJsAccessible, $retainObjcAnnotated, $retainUnusedProtocolFuncParams, $retainUnusedParametersWithoutDefault, $retainSwiftUIPreviews, $disableRedundantPublicAnalysis, $enableRedundantPublicMembers, $enableOpenFinalAnalysis, $enableEmptyExtensionAnalysis, $enableRedundantAccessLevelAnalysis, $reportUnusedTypeParameters,
        $disablePlatformConditionalRetention, $disableUnusedImportAnalysis, $enableUnusedSystemImports, $disableUnusedLocalizedStringAnalysis, $localizedStringCatalogExclude, $localizedStringKeyPatterns, $localizedStringKeyLiteralMatch, $retainRuntimeLocalizedKeys, $superfluousIgnoreComments, $retainUnusedImportedModules,
        $externalEncodableProtocols, $externalCodableProtocols, $externalTestCaseClasses, $verbose, $quiet, $color,
        $disableUpdateCheck, $strict, $indexStorePath,
        $skipBuild, $skipSchemesValidation, $cleanBuild, $cacheMaxAgeDays, $cacheMaxSizeGB, $buildArguments, $xcodeListArguments, $relativeResults, $relativeResultsBase, $changedSince, $changedLines,
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

    /// The configuration file to read: the given one, which must exist, or else the first existing default file.
    public func configurationPath(withUserProvided path: FilePath?) throws -> FilePath? {
        if let path {
            if !path.exists {
                throw PeripheryError.pathDoesNotExist(path: path.lexicallyNormalized().string)
            }

            return path
        }

        return Self.configurationFileNames.map { FilePath($0) }.first { $0.exists }
    }
}

// MARK: - Yaml Encoding

extension OutputFormat: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        rawValue.represented()
    }
}

extension FilePath: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        string.represented()
    }
}

extension ColorOption: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        rawValue.represented()
    }
}
