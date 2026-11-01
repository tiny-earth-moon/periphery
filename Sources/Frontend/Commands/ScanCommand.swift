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

    @Option(help: "Output format")
    var format: OutputFormat = defaultConfiguration.$outputFormat.defaultValue

    @Flag(help: "Exclude test targets from indexing")
    var excludeTests: Bool = defaultConfiguration.$excludeTests.defaultValue

    @Option(parsing: .upToNextOption, help: "Targets to exclude from indexing")
    var excludeTargets: [String] = defaultConfiguration.$excludeTargets.defaultValue

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from indexing")
    var indexExclude: [String] = defaultConfiguration.$indexExclude.defaultValue

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from the results, optionally limited to result kinds with '<glob>:kind1,kind2'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to include in the results. This option supersedes '--report-exclude'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportInclude: [String] = defaultConfiguration.$reportInclude.defaultValue

    @Option(parsing: .upToNextOption, help: "Source file globs for which all containing declarations will be retained")
    var retainFiles: [String] = defaultConfiguration.$retainFiles.defaultValue

    @Option(parsing: .upToNextOption, help: "Index store paths. Implies '--skip-build'")
    var indexStorePath: [FilePath] = defaultConfiguration.$indexStorePath.defaultValue

    @Flag(help: "Retain all public declarations, recommended for framework/library projects")
    var retainPublic: Bool = defaultConfiguration.$retainPublic.defaultValue

    @Option(parsing: .upToNextOption, help: "Public SPIs (System Programming Interfaces) to check for unused code even when '--retain-public' is enabled")
    var noRetainSPI: [String] = defaultConfiguration.$noRetainSPI.defaultValue

    @Flag(help: "Disable retention of declarations that are unavailable on a platform, or referenced from platform conditional compilation blocks")
    var disablePlatformConditionalRetention: Bool = defaultConfiguration.$disablePlatformConditionalRetention.defaultValue

    @Flag(help: "Disable identification of redundant public accessibility")
    var disableRedundantPublicAnalysis: Bool = defaultConfiguration.$disableRedundantPublicAnalysis.defaultValue

    @Flag(help: "Disable identification of unused imports")
    var disableUnusedImportAnalysis: Bool = defaultConfiguration.$disableUnusedImportAnalysis.defaultValue

    @Flag(inversion: .prefixedNo, help: "Report superfluous ignore comments")
    var superfluousIgnoreComments: Bool = defaultConfiguration.$superfluousIgnoreComments.defaultValue
    @Flag(help: "Disable identification of unused localized strings from String Catalogs (xcstrings)")
    var disableUnusedLocalizedStringAnalysis: Bool = defaultConfiguration.$disableUnusedLocalizedStringAnalysis.defaultValue

    @Option(parsing: .upToNextOption, help: "String Catalog (xcstrings) file globs to exclude from unused localized string analysis")
    var localizedStringCatalogExclude: [String] = defaultConfiguration.$localizedStringCatalogExclude.defaultValue

    @Option(parsing: .upToNextOption, help: "Localized string key patterns (globs, or regular expressions between slashes) of keys used dynamically, retained from String Catalogs (xcstrings)")
    var localizedStringKeyPatterns: [String] = defaultConfiguration.$localizedStringKeyPatterns.defaultValue

    @Flag(help: "Retain localized string keys equal to any string literal of the source, whatever its type or position")
    var localizedStringKeyLiteralMatch: Bool = defaultConfiguration.$localizedStringKeyLiteralMatch.defaultValue

    @Flag(help: "Retain every String Catalog key that a localized string key built at runtime without a literal prefix may look up")
    var retainRuntimeLocalizedKeys: Bool = defaultConfiguration.$retainRuntimeLocalizedKeys.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of unused imported modules to retain")
    var retainUnusedImportedModules: [String] = defaultConfiguration.$retainUnusedImportedModules.defaultValue

    @Flag(help: "Retain properties that are assigned, but never used")
    var retainAssignOnlyProperties: Bool = defaultConfiguration.$retainAssignOnlyProperties.defaultValue

    @Option(parsing: .upToNextOption, help: "Property types to retain if the property is assigned, but never read")
    var retainAssignOnlyPropertyTypes: [String] = defaultConfiguration.$retainAssignOnlyPropertyTypes.defaultValue

    @Flag(help: "Report optional properties that are read, but never assigned (always nil)")
    var enableUnassignedOptionalAnalysis: Bool = defaultConfiguration.$enableUnassignedOptionalAnalysis.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of external protocols that inherit Encodable. Properties and CodingKey enums of types conforming to these protocols will be retained")
    var externalEncodableProtocols: [String] = defaultConfiguration.$externalEncodableProtocols.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of external protocols that inherit Codable. Properties and CodingKey enums of types conforming to these protocols will be retained")
    var externalCodableProtocols: [String] = defaultConfiguration.$externalCodableProtocols.defaultValue

    @Option(parsing: .upToNextOption, help: "Names of XCTestCase subclasses that reside in external targets")
    var externalTestCaseClasses: [String] = defaultConfiguration.$externalTestCaseClasses.defaultValue

    @Flag(help: "Retain declarations that are exposed to Objective-C implicitly by inheriting NSObject classes, or explicitly with the @objc and @objcMembers attributes")
    var retainObjcAccessible: Bool = defaultConfiguration.$retainObjcAccessible.defaultValue

    @Flag(help: "Retain protocols that inherit JSExport, their members, and the members of conforming types that satisfy them")
    var retainJsAccessible: Bool = defaultConfiguration.$retainJsAccessible.defaultValue

    @Flag(help: "Retain declarations that are exposed to Objective-C explicitly with the @objc and @objcMembers attributes")
    var retainObjcAnnotated: Bool = defaultConfiguration.$retainObjcAnnotated.defaultValue

    @Flag(help: "Retain unused protocol function parameters, even if the parameter is unused in all conforming functions")
    var retainUnusedProtocolFuncParams: Bool = defaultConfiguration.$retainUnusedProtocolFuncParams.defaultValue

    @Flag(help: "Retain unused function parameters that have no default value, as removing them would break callers")
    var retainUnusedParametersWithoutDefault: Bool = defaultConfiguration.$retainUnusedParametersWithoutDefault.defaultValue

    @Flag(help: "Retain SwiftUI previews")
    var retainSwiftUIPreviews: Bool = defaultConfiguration.$retainSwiftUIPreviews.defaultValue

    @Flag(help: "Retain properties on Codable types (including Encodable and Decodable)")
    var retainCodableProperties: Bool = defaultConfiguration.$retainCodableProperties.defaultValue

    @Flag(help: "Retain properties on Encodable types only")
    var retainEncodableProperties: Bool = defaultConfiguration.$retainEncodableProperties.defaultValue

    @Flag(help: "Retain properties on Equatable types, including Hashable types")
    var retainEquatableProperties: Bool = defaultConfiguration.$retainEquatableProperties.defaultValue

    @Flag(help: "Retain properties on Hashable types")
    var retainHashableProperties: Bool = defaultConfiguration.$retainHashableProperties.defaultValue

    @Flag(help: "Clean existing build artifacts before building")
    var cleanBuild: Bool = defaultConfiguration.$cleanBuild.defaultValue

    @Flag(help: "Skip the project build step")
    var skipBuild: Bool = defaultConfiguration.$skipBuild.defaultValue

    @Flag(help: "Skip schemes validation")
    var skipSchemesValidation: Bool = defaultConfiguration.$skipSchemesValidation.defaultValue

    @Flag(help: "Output result paths relative to the current directory")
    var relativeResults: Bool = defaultConfiguration.$relativeResults.defaultValue

    @Flag(help: "Exit with non-zero status if any unused code is found")
    var strict: Bool = defaultConfiguration.$strict.defaultValue

    @Flag(help: "Disable checking for updates")
    var disableUpdateCheck: Bool = defaultConfiguration.$disableUpdateCheck.defaultValue

    @Flag(help: "Enable verbose logging")
    var verbose: Bool = defaultConfiguration.$verbose.defaultValue

    @Flag(help: "Only output results")
    var quiet: Bool = defaultConfiguration.$quiet.defaultValue

    @Option(help: "Colored output mode")
    var color: ColorOption = defaultConfiguration.$color.defaultValue

    @Flag(name: .customLong("no-color"), help: .hidden)
    var noColor: Bool = false

    @Option(help: "JSON package manifest path (obtained using `swift package describe --type json` or manually)")
    var jsonPackageManifestPath: FilePath?

    @Option(help: "Maximum age in days of unused Xcode build caches before they are evicted at the end of a scan. 0 disables eviction.")
    var cacheMaxAgeDays: Int = defaultConfiguration.$cacheMaxAgeDays.defaultValue

    @Option(help: "Baseline file path used to filter results")
    var baseline: FilePath?

    @Option(help: "Baseline file path where results are written. Pass the same path to '--baseline' in subsequent scans to exclude the results recorded in the baseline.")
    var writeBaseline: FilePath?

    @Option(help: "File path where formatted results are written.")
    var writeResults: FilePath?

    @Option(help: "Project configuration for non-Apple build systems")
    var genericProjectConfig: FilePath?

    @Flag(help: "Enable Bazel project mode")
    var bazel: Bool = defaultConfiguration.$bazel.defaultValue

    @Option(help: "Filter pattern applied to the Bazel top-level targets query")
    var bazelFilter: String?

    @Option(help: "Query expression used for the Bazel top-level targets query. Overrides the default query and bypasses bazelFilter.")
    var bazelQuery: String?

    @Option(help: "Path to a global index store populated by Bazel. If provided, will be used instead of individual module stores.")
    var bazelIndexStore: FilePath?

    @Flag(help: "Enable Bazel visibility checking")
    var bazelCheckVisibility: Bool = defaultConfiguration.$bazelCheckVisibility.defaultValue

    @Flag(help: "Retain stored properties of types whose values are described through reflection, e.g. passed to print, dump, String(describing:) or string interpolation")
    var retainSynthesizedUses: Bool = defaultConfiguration.$retainSynthesizedUses.defaultValue

    @Option(parsing: .upToNextOption, help: "Retain declarations that have any of the given attributes (without the '@'), optionally limited to declaration kinds with '<attribute>:kind1,kind2', e.g. 'OptionGroup' or 'objc:function.method.instance'")
    var retainAttributes: [String] = defaultConfiguration.$retainAttributes.defaultValue

    @Flag(help: "Report unused colors of Xcode asset catalogs, analyzing the symbols Xcode generates for them in GeneratedAssetSymbols.swift (indexed despite '--index-exclude')")
    var detectUnusedAssetCatalogColors: Bool = defaultConfiguration.$detectUnusedAssetCatalogColors.defaultValue

    private static let defaultConfiguration = Configuration()

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
        configuration.apply(\.$project, project)
        configuration.apply(\.$schemes, schemes)
        configuration.apply(\.$indexExclude, indexExclude)
        configuration.apply(\.$reportExclude, reportExclude.map { .pattern($0) })
        configuration.apply(\.$reportInclude, reportInclude)
        configuration.apply(\.$outputFormat, format)
        configuration.apply(\.$retainFiles, retainFiles)
        configuration.apply(\.$retainPublic, retainPublic)
        configuration.apply(\.$noRetainSPI, noRetainSPI)
        configuration.apply(\.$retainAssignOnlyProperties, retainAssignOnlyProperties)
        configuration.apply(\.$retainAssignOnlyPropertyTypes, retainAssignOnlyPropertyTypes)
        configuration.apply(\.$enableUnassignedOptionalAnalysis, enableUnassignedOptionalAnalysis)
        configuration.apply(\.$retainObjcAccessible, retainObjcAccessible)
        configuration.apply(\.$retainJsAccessible, retainJsAccessible)
        configuration.apply(\.$retainObjcAnnotated, retainObjcAnnotated)
        configuration.apply(\.$retainUnusedProtocolFuncParams, retainUnusedProtocolFuncParams)
        configuration.apply(\.$retainUnusedParametersWithoutDefault, retainUnusedParametersWithoutDefault)
        configuration.apply(\.$retainSwiftUIPreviews, retainSwiftUIPreviews)
        configuration.apply(\.$disableRedundantPublicAnalysis, disableRedundantPublicAnalysis)
        configuration.apply(\.$disablePlatformConditionalRetention, disablePlatformConditionalRetention)
        configuration.apply(\.$disableUnusedImportAnalysis, disableUnusedImportAnalysis)
        configuration.apply(\.$superfluousIgnoreComments, superfluousIgnoreComments)
        configuration.apply(\.$disableUnusedLocalizedStringAnalysis, disableUnusedLocalizedStringAnalysis)
        configuration.apply(\.$localizedStringCatalogExclude, localizedStringCatalogExclude)
        configuration.apply(\.$localizedStringKeyPatterns, localizedStringKeyPatterns)
        configuration.apply(\.$localizedStringKeyLiteralMatch, localizedStringKeyLiteralMatch)
        configuration.apply(\.$retainRuntimeLocalizedKeys, retainRuntimeLocalizedKeys)
        configuration.apply(\.$retainUnusedImportedModules, retainUnusedImportedModules)
        configuration.apply(\.$externalEncodableProtocols, externalEncodableProtocols)
        configuration.apply(\.$externalCodableProtocols, externalCodableProtocols)
        configuration.apply(\.$externalTestCaseClasses, externalTestCaseClasses)
        configuration.apply(\.$verbose, verbose)
        configuration.apply(\.$quiet, quiet)
        configuration.apply(\.$color, noColor ? .never : color)
        configuration.apply(\.$disableUpdateCheck, disableUpdateCheck)
        configuration.apply(\.$strict, strict)
        configuration.apply(\.$indexStorePath, indexStorePath)
        configuration.apply(\.$skipBuild, skipBuild)
        configuration.apply(\.$excludeTests, excludeTests)
        configuration.apply(\.$excludeTargets, excludeTargets)
        configuration.apply(\.$skipSchemesValidation, skipSchemesValidation)
        configuration.apply(\.$cleanBuild, cleanBuild)
        configuration.apply(\.$cacheMaxAgeDays, cacheMaxAgeDays)
        configuration.apply(\.$buildArguments, buildArguments)
        configuration.apply(\.$relativeResults, relativeResults)
        configuration.apply(\.$retainCodableProperties, retainCodableProperties)
        configuration.apply(\.$retainEncodableProperties, retainEncodableProperties)
        configuration.apply(\.$retainEquatableProperties, retainEquatableProperties)
        configuration.apply(\.$retainHashableProperties, retainHashableProperties)
        configuration.apply(\.$jsonPackageManifestPath, jsonPackageManifestPath)
        configuration.apply(\.$baseline, baseline)
        configuration.apply(\.$writeBaseline, writeBaseline)
        configuration.apply(\.$writeResults, writeResults)
        configuration.apply(\.$genericProjectConfig, genericProjectConfig)
        configuration.apply(\.$bazel, bazel)
        configuration.apply(\.$bazelFilter, bazelFilter)
        configuration.apply(\.$bazelQuery, bazelQuery)
        configuration.apply(\.$bazelIndexStore, bazelIndexStore)
        configuration.apply(\.$bazelCheckVisibility, bazelCheckVisibility)
        configuration.apply(\.$retainSynthesizedUses, retainSynthesizedUses)
        configuration.apply(\.$retainAttributes, retainAttributes)
        configuration.apply(\.$detectUnusedAssetCatalogColors, detectUnusedAssetCatalogColors)

        configuration.buildFilenameMatchers()
        _ = try ReportExcludeRule.resolve(configuration)
        _ = try AttributeRetentionRule.resolve(configuration)

        let logger = Logger(configuration: configuration)
        logger.contextualized(with: "version").debug(PeripheryVersion)
        let shell = ShellImpl(logger: logger) {
            logger.warn(
                "Termination can result in a corrupt index. Try the '--clean-build' flag if you get erroneous results such as false-positives and incorrect source file locations.",
                newlinePrefix: true // Print a newline after ^C
            )
        }
        let swiftVersion = SwiftVersion(shell: shell)
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

        let planSuggester = PlanSuggester(
            logger: logger,
            loc: scanOutput.loc
        )
        planSuggester.run()

        let results = scanOutput.results
        let interval = logger.beginInterval("result:output")
        var baseline: Baseline?

        if let baselinePath = configuration.baseline {
            let data = try Data(contentsOf: baselinePath.url)
            baseline = try JSONDecoder().decode(Baseline.self, from: data)
        }

        let filteredResults = try OutputDeclarationFilter(configuration: configuration, logger: logger).filter(results, with: baseline)

        if let baselinePath = configuration.writeBaseline {
            let usrs = filteredResults
                .flatMapSet { $0.usrs }
                .union(baseline?.usrs ?? [])
            let baseline = Baseline.v1(usrs: usrs.sorted())
            let data = try JSONEncoder().encode(baseline)
            try data.write(to: baselinePath.url)
        }

        let outputFormat = configuration.outputFormat
        let formatter = outputFormat.formatter.init(configuration: configuration, logger: logger)
        let colored = outputFormat.supportsColoredOutput && logger.isColoredOutputEnabled

        let formattedOutput = try formatter.format(filteredResults, colored: colored)

        if let output = formattedOutput {
            if outputFormat.supportsAuxiliaryOutput {
                logger.info("", canQuiet: true)
            }

            logger.info(output, canQuiet: false)
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
        planSuggester.notifyIfSuggested()

        if !filteredResults.isEmpty, configuration.strict {
            throw PeripheryError.foundIssues(count: filteredResults.count)
        }
    }

    // MARK: - Private

    private static var projectRootDefault: FilePath {
        let bazelWorkspace = ProcessInfo.processInfo.environment["BUILD_WORKSPACE_DIRECTORY"]
        let root = bazelWorkspace ?? FileManager.default.currentDirectoryPath
        return FilePath(root)
    }
}

extension OutputFormat: ArgumentParser.ExpressibleByArgument {}
extension ColorOption: ArgumentParser.ExpressibleByArgument {}

extension FilePath: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}
