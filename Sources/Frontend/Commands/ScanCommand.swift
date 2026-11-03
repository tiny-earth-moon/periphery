import ArgumentParser
import Configuration
import Foundation
import Logger
import PeripheryKit
import Shared
import SourceGraph
import SystemPackage

struct ScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan for unused code"
    )

    @Argument(help: "Arguments following '--' will be passed to the underlying build tool, which is either 'swift build' or 'xcodebuild' depending on your project")
    var buildArguments: [String] = defaultConfiguration.$buildArguments.defaultValue

    @Flag(help: "Enable guided setup")
    var setup: Bool = defaultConfiguration.guidedSetup

    @Option(help: "Path to the root directory of your project")
    var projectRoot: FilePath = projectRootDefault

    @Option(help: "Path to configuration file. By default Periphery will look for .periphery.yml in the current directory")
    var config: FilePath?

    @Option(help: "Path to your project's .xcodeproj or .xcworkspace")
    var project: FilePath?

    @Option(parsing: .upToNextOption, help: "Schemes to build. All targets built by these schemes will be scanned")
    var schemes: [String] = defaultConfiguration.$schemes.defaultValue

    @Option(help: "Output format (default: xcode)")
    var format: OutputFormat?

    @Flag(inversion: .prefixedNo, help: "Exclude test targets from indexing")
    var excludeTests: Bool?

    @Option(parsing: .upToNextOption, help: "Targets to exclude from indexing")
    var excludeTargets: [String] = defaultConfiguration.$excludeTargets.defaultValue

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from indexing, in addition to the default ones (default: **/*?.build/**/*, **/SourcePackages/checkouts/**)")
    var indexExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from the results, optionally limited to result kinds with '<glob>:kind1,kind2'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to include in the results. This option supersedes '--report-exclude'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportInclude: [String] = defaultConfiguration.$reportInclude.defaultValue

    @Option(parsing: .upToNextOption, help: "Source file globs for which all containing declarations will be retained")
    var retainFiles: [String] = defaultConfiguration.$retainFiles.defaultValue

    @Option(parsing: .upToNextOption, help: "Index store paths. Implies '--skip-build'")
    var indexStorePath: [FilePath] = defaultConfiguration.$indexStorePath.defaultValue

    @Flag(inversion: .prefixedNo, help: "Retain all public declarations, recommended for framework/library projects")
    var retainPublic: Bool?

    @Option(parsing: .upToNextOption, help: "Public SPIs (System Programming Interfaces) to check for unused code even when '--retain-public' is enabled")
    var noRetainSPI: [String] = defaultConfiguration.$noRetainSPI.defaultValue

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

    @Option(parsing: .upToNextOption, help: "Names of unused imported modules to retain")
    var retainUnusedImportedModules: [String] = defaultConfiguration.$retainUnusedImportedModules.defaultValue

    @Flag(inversion: .prefixedNo, help: "Retain properties that are assigned, but never used")
    var retainAssignOnlyProperties: Bool?

    @Option(parsing: .upToNextOption, help: "Property types to retain if the property is assigned, but never read")
    var retainAssignOnlyPropertyTypes: [String] = defaultConfiguration.$retainAssignOnlyPropertyTypes.defaultValue

    @Flag(inversion: .prefixedNo, help: "Report optional properties that are read, but never assigned (always nil)")
    var enableUnassignedOptionalAnalysis: Bool?

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

    @Flag(inversion: .prefixedNo, help: "Clean existing build artifacts before building")
    var cleanBuild: Bool?

    @Flag(inversion: .prefixedNo, help: "Skip the project build step")
    var skipBuild: Bool?

    @Flag(inversion: .prefixedNo, help: "Skip schemes validation")
    var skipSchemesValidation: Bool?

    @Flag(inversion: .prefixedNo, help: "Output result paths relative to the current directory")
    var relativeResults: Bool?

    @Flag(inversion: .prefixedNo, help: "Exit with non-zero status if any unused code is found")
    var strict: Bool?

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

    @Option(help: "JSON package manifest path (obtained using `swift package describe --type json` or manually)")
    var jsonPackageManifestPath: FilePath?

    @Option(help: "Maximum age in days of unused Xcode build caches before they are evicted at the end of a scan. 0 disables eviction (default: 14)")
    var cacheMaxAgeDays: Int?

    @Option(help: "Baseline file path used to filter results")
    var baseline: FilePath?

    @Option(help: "Baseline file path where results are written. Pass the same path to '--baseline' in subsequent scans to exclude the results recorded in the baseline.")
    var writeBaseline: FilePath?

    @Flag(inversion: .prefixedNo, help: "Rewrite the file given to '--baseline' keeping only the entries that still match a result. Requires '--baseline'")
    var pruneBaseline: Bool?

    @Flag(inversion: .prefixedNo, help: "Exit with non-zero status (1, like '--strict') if the baseline holds entries that no longer match any result. Requires '--baseline'. Not applied when '--prune-baseline' removes the entries")
    var strictBaseline: Bool?

    @Option(help: "File path where formatted results are written.")
    var writeResults: FilePath?

    @Flag(help: "Do not print the results to stdout. Requires '--write-results'")
    var skipStdoutResults: Bool = defaultConfiguration.$skipStdoutResults.defaultValue

    @Option(help: "Project configuration for non-Apple build systems")
    var genericProjectConfig: FilePath?

    @Flag(inversion: .prefixedNo, help: "Retain stored properties of types whose values are described through reflection, e.g. passed to print, dump, String(describing:) or string interpolation")
    var retainSynthesizedUses: Bool?

    @Option(parsing: .upToNextOption, help: "Retain declarations that have any of the given attributes (without the '@'), optionally limited to declaration kinds with '<attribute>:kind1,kind2', e.g. 'OptionGroup' or 'objc:function.method.instance'")
    var retainAttributes: [String] = defaultConfiguration.$retainAttributes.defaultValue

    @Flag(inversion: .prefixedNo, help: "Report unused colors of Xcode asset catalogs, analyzing the symbols Xcode generates for them in GeneratedAssetSymbols.swift (indexed despite '--index-exclude')")
    var detectUnusedAssetCatalogColors: Bool?

    @Flag(inversion: .prefixedNo, help: "Report unused images of Xcode asset catalogs, analyzing the symbols Xcode generates for them in GeneratedAssetSymbols.swift (indexed despite '--index-exclude')")
    var detectUnusedAssetCatalogImages: Bool?

    @OptionGroup(visibility: .hidden)
    var removedBazelOptions: RemovedBazelOptions

    private static let defaultConfiguration = Configuration()

    func validate() throws {
        try removedBazelOptions.rejectUse()
    }

    /// Applies the options given on the command line to a configuration that holds the values of the configuration file.
    func apply(to configuration: Configuration) {
        configuration.apply(\.$project, project)
        configuration.apply(\.$schemes, given(schemes))
        configuration.apply(\.$indexExclude, given(indexExclude))
        configuration.apply(\.$reportExclude, given(reportExclude).map { $0.map { .pattern($0) } })
        configuration.apply(\.$reportInclude, given(reportInclude))
        configuration.apply(\.$outputFormat, format)
        configuration.apply(\.$retainFiles, given(retainFiles))
        configuration.apply(\.$retainPublic, retainPublic)
        configuration.apply(\.$noRetainSPI, given(noRetainSPI))
        configuration.apply(\.$retainAssignOnlyProperties, retainAssignOnlyProperties)
        configuration.apply(\.$retainAssignOnlyPropertyTypes, given(retainAssignOnlyPropertyTypes))
        configuration.apply(\.$enableUnassignedOptionalAnalysis, enableUnassignedOptionalAnalysis)
        configuration.apply(\.$retainObjcAccessible, retainObjcAccessible)
        configuration.apply(\.$retainJsAccessible, retainJsAccessible)
        configuration.apply(\.$retainObjcAnnotated, retainObjcAnnotated)
        configuration.apply(\.$retainUnusedProtocolFuncParams, retainUnusedProtocolFuncParams)
        configuration.apply(\.$retainUnusedParametersWithoutDefault, retainUnusedParametersWithoutDefault)
        configuration.apply(\.$retainSwiftUIPreviews, retainSwiftUIPreviews)
        configuration.apply(\.$disableRedundantPublicAnalysis, disableRedundantPublicAnalysis)
        configuration.apply(\.$enableRedundantPublicMembers, enableRedundantPublicMembers)
        configuration.apply(\.$enableOpenFinalAnalysis, enableOpenFinalAnalysis)
        configuration.apply(\.$enableEmptyExtensionAnalysis, enableEmptyExtensionAnalysis)
        configuration.apply(\.$enableRedundantAccessLevelAnalysis, enableRedundantAccessLevelAnalysis)
        configuration.apply(\.$reportUnusedTypeParameters, reportUnusedTypeParameters)
        configuration.apply(\.$disablePlatformConditionalRetention, disablePlatformConditionalRetention)
        configuration.apply(\.$disableUnusedImportAnalysis, disableUnusedImportAnalysis)
        configuration.apply(\.$enableUnusedSystemImports, enableUnusedSystemImports)
        configuration.apply(\.$superfluousIgnoreComments, superfluousIgnoreComments)
        configuration.apply(\.$disableUnusedLocalizedStringAnalysis, disableUnusedLocalizedStringAnalysis)
        configuration.apply(\.$localizedStringCatalogExclude, given(localizedStringCatalogExclude))
        configuration.apply(\.$localizedStringKeyPatterns, given(localizedStringKeyPatterns))
        configuration.apply(\.$localizedStringKeyLiteralMatch, localizedStringKeyLiteralMatch)
        configuration.apply(\.$retainRuntimeLocalizedKeys, retainRuntimeLocalizedKeys)
        configuration.apply(\.$retainUnusedImportedModules, given(retainUnusedImportedModules))
        configuration.apply(\.$externalEncodableProtocols, given(externalEncodableProtocols))
        configuration.apply(\.$externalCodableProtocols, given(externalCodableProtocols))
        configuration.apply(\.$externalTestCaseClasses, given(externalTestCaseClasses))
        configuration.apply(\.$verbose, verbose)
        configuration.apply(\.$quiet, quiet)
        configuration.apply(\.$color, noColor ? .never : color)
        configuration.apply(\.$disableUpdateCheck, disableUpdateCheck)
        configuration.apply(\.$strict, strict)
        configuration.apply(\.$indexStorePath, given(indexStorePath))
        configuration.apply(\.$skipBuild, skipBuild)
        configuration.apply(\.$excludeTests, excludeTests)
        configuration.apply(\.$excludeTargets, given(excludeTargets))
        configuration.apply(\.$skipSchemesValidation, skipSchemesValidation)
        configuration.apply(\.$cleanBuild, cleanBuild)
        configuration.apply(\.$cacheMaxAgeDays, cacheMaxAgeDays)
        configuration.apply(\.$buildArguments, given(buildArguments))
        configuration.apply(\.$relativeResults, relativeResults)
        configuration.apply(\.$retainCodableProperties, retainCodableProperties)
        configuration.apply(\.$retainEncodableProperties, retainEncodableProperties)
        configuration.apply(\.$retainEquatableProperties, retainEquatableProperties)
        configuration.apply(\.$retainHashableProperties, retainHashableProperties)
        configuration.apply(\.$jsonPackageManifestPath, jsonPackageManifestPath)
        configuration.apply(\.$baseline, baseline)
        configuration.apply(\.$writeBaseline, writeBaseline)
        configuration.apply(\.$pruneBaseline, pruneBaseline)
        configuration.apply(\.$strictBaseline, strictBaseline)
        configuration.apply(\.$writeResults, writeResults)
        configuration.apply(\.$skipStdoutResults, skipStdoutResults)
        configuration.apply(\.$genericProjectConfig, genericProjectConfig)
        configuration.apply(\.$retainSynthesizedUses, retainSynthesizedUses)
        configuration.apply(\.$retainAttributes, given(retainAttributes))
        configuration.apply(\.$detectUnusedAssetCatalogColors, detectUnusedAssetCatalogColors)
        configuration.apply(\.$detectUnusedAssetCatalogImages, detectUnusedAssetCatalogImages)
    }

    func run() throws {
        if !FileManager.default.changeCurrentDirectoryPath(projectRoot.string) {
            throw PeripheryError.changeCurrentDirectoryFailed(projectRoot)
        }

        let configuration = Configuration()

        if !setup {
            try configuration.load(from: config)
        }

        configuration.guidedSetup = setup
        configuration.projectRoot = projectRoot
        apply(to: configuration)

        if configuration.skipStdoutResults, configuration.writeResults == nil {
            throw PeripheryError.usageError("The '--skip-stdout-results' option requires '--write-results', otherwise the results would not be output anywhere.")
        }

        configuration.buildFilenameMatchers()
        _ = try ReportExcludeRule.resolve(configuration)
        _ = try AttributeRetentionRule.resolve(configuration)
        let baseline = try ScanPreflight.validatePaths(of: configuration)

        let logger = Logger(configuration: configuration)
        ScanPreflight.applyOutputFormatRequirements(to: configuration, logger: logger)
        logger.contextualized(with: "version").debug(PeripheryVersion)
        let shell = ShellImpl(logger: logger) {
            logger.warn(
                "Termination can result in a corrupt index. Try the '--clean-build' flag if you get erroneous results such as false-positives and incorrect source file locations.",
                newlinePrefix: true // Print a newline after ^C
            )
        }
        let swiftVersion = try SwiftVersion(shell: shell)
        logger.debug(swiftVersion.fullVersion)
        try swiftVersion.validateVersion()

        let project: Project = if configuration.guidedSetup {
            try GuidedSetup(configuration: configuration, shell: shell, logger: logger).perform()
        } else {
            try Project(configuration: configuration, shell: shell, logger: logger)
        }

        let updateChecker = UpdateChecker(logger: logger, configuration: configuration)
        updateChecker.run()

        let scanOutput = try Scan(
            configuration: configuration,
            logger: logger,
            swiftVersion: swiftVersion
        ).perform(project: project)

        let results = scanOutput.results
        let interval = logger.beginInterval("result:output")

        let outputFilter = OutputDeclarationFilter(configuration: configuration, logger: logger)
        let filteredResults = try outputFilter.filter(results, with: baseline)

        if configuration.pruneBaseline, let baselinePath = configuration.baseline {
            try Self.writeBaseline(.pruned(keeping: outputFilter.baselineMatchedResults), to: baselinePath)
            logger.info("Pruned \(outputFilter.staleBaselineEntries.count) stale entries from \(baselinePath.string)")
        }

        if let baselinePath = configuration.writeBaseline {
            try Self.writeBaseline(.written(from: filteredResults, union: baseline), to: baselinePath)
        }

        let outputFormat = configuration.outputFormat
        let formatter = outputFormat.formatter.init(configuration: configuration, logger: logger)
        let colored = outputFormat.supportsColoredOutput && logger.isColoredOutputEnabled

        let formattedOutput = try formatter.format(filteredResults, colored: colored)

        if let output = formattedOutput, !configuration.skipStdoutResults {
            if outputFormat.supportsAuxiliaryOutput {
                logger.info("", canQuiet: true)
            }

            logger.output(output)
        }

        if let resultsPath = configuration.writeResults {
            let output: String = if colored {
                // The formatted output contains ANSI escape codes, so we need to re-format
                // with coloring disabled.
                try formatter.format(filteredResults, colored: false) ?? ""
            } else {
                formattedOutput ?? ""
            }

            try output.write(to: resultsPath.url, atomically: true, encoding: .utf8)
        }

        logger.endInterval(interval)

        updateChecker.notifyIfAvailable()

        if !filteredResults.isEmpty, configuration.strict {
            throw PeripheryError.foundIssues(count: filteredResults.count)
        }

        if let failure = Self.staleBaselineFailure(configuration: configuration, staleEntryCount: outputFilter.staleBaselineEntries.count) {
            throw failure
        }
    }

    /// The error that ends the scan with a non-zero status when `--strict-baseline` finds stale entries, which
    /// `--prune-baseline` has just removed.
    static func staleBaselineFailure(configuration: Configuration, staleEntryCount: Int) -> PeripheryError? {
        guard configuration.strictBaseline, !configuration.pruneBaseline, staleEntryCount > 0 else { return nil }

        return .staleBaselineEntries(count: staleEntryCount)
    }

    static func writeBaseline(_ baseline: Baseline, to path: FilePath) throws {
        try baseline.write(to: path)
    }

    // MARK: - Private

    /// The values of a list option, or nil when the option was not passed: ArgumentParser reports an option that is not passed as an empty list.
    private func given<T>(_ values: [T]) -> [T]? {
        values.isEmpty ? nil : values
    }

    private static var projectRootDefault: FilePath {
        FilePath(FileManager.default.currentDirectoryPath)
    }
}

extension OutputFormat: ArgumentParser.ExpressibleByArgument {}
extension ColorOption: ArgumentParser.ExpressibleByArgument {}

extension FilePath: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}
