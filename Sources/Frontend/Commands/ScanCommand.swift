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

    @OptionGroup(title: "Project")
    var projectOptions: ProjectOptions

    @OptionGroup(title: "Build")
    var buildOptions: BuildOptions

    @OptionGroup(title: "Analysis")
    var analysisOptions: AnalysisOptions

    @OptionGroup(title: "Retention")
    var retentionOptions: RetentionOptions

    @OptionGroup(title: "Results")
    var resultsOptions: ResultsOptions

    @OptionGroup(title: "Baseline")
    var baselineOptions: BaselineOptions

    @OptionGroup(title: "Localized strings")
    var localizedStringOptions: LocalizedStringOptions

    @OptionGroup(title: "Miscellaneous")
    var miscellaneousOptions: MiscellaneousOptions

    @OptionGroup(visibility: .hidden)
    var removedBazelOptions: RemovedBazelOptions

    func validate() throws {
        try removedBazelOptions.rejectUse()
    }

    /// Applies the options given on the command line to a configuration that holds the values of the configuration file.
    func apply(to configuration: Configuration) {
        configuration.apply(\.$project, projectOptions.project)
        configuration.apply(\.$schemes, given(projectOptions.schemes))
        configuration.apply(\.$indexExclude, given(buildOptions.indexExclude))
        configuration.apply(\.$reportExclude, given(resultsOptions.reportExclude).map { $0.map { .pattern($0) } })
        configuration.apply(\.$reportInclude, given(resultsOptions.reportInclude))
        configuration.apply(\.$outputFormat, resultsOptions.format)
        configuration.apply(\.$retainFiles, given(retentionOptions.retainFiles))
        configuration.apply(\.$retainPublic, retentionOptions.retainPublic)
        configuration.apply(\.$retainPublicModules, given(retentionOptions.retainPublicModules) ?? (retentionOptions.retainPublic == false ? [] : nil))
        configuration.apply(\.$noRetainSPI, given(retentionOptions.noRetainSPI))
        configuration.apply(\.$retainAssignOnlyProperties, retentionOptions.retainAssignOnlyProperties)
        configuration.apply(\.$retainAssignOnlyPropertyTypes, given(retentionOptions.retainAssignOnlyPropertyTypes))
        configuration.apply(\.$enableUnassignedOptionalAnalysis, analysisOptions.enableUnassignedOptionalAnalysis)
        configuration.apply(\.$retainObjcAccessible, retentionOptions.retainObjcAccessible)
        configuration.apply(\.$retainJsAccessible, retentionOptions.retainJsAccessible)
        configuration.apply(\.$retainObjcAnnotated, retentionOptions.retainObjcAnnotated)
        configuration.apply(\.$retainUnusedProtocolFuncParams, retentionOptions.retainUnusedProtocolFuncParams)
        configuration.apply(\.$retainUnusedParametersWithoutDefault, retentionOptions.retainUnusedParametersWithoutDefault)
        configuration.apply(\.$retainSwiftUIPreviews, retentionOptions.retainSwiftUIPreviews)
        configuration.apply(\.$disableRedundantPublicAnalysis, analysisOptions.disableRedundantPublicAnalysis)
        configuration.apply(\.$enableRedundantPublicMembers, analysisOptions.enableRedundantPublicMembers)
        configuration.apply(\.$enableOpenFinalAnalysis, analysisOptions.enableOpenFinalAnalysis)
        configuration.apply(\.$enableEmptyExtensionAnalysis, analysisOptions.enableEmptyExtensionAnalysis)
        configuration.apply(\.$enableRedundantAccessLevelAnalysis, analysisOptions.enableRedundantAccessLevelAnalysis)
        configuration.apply(\.$reportUnusedTypeParameters, analysisOptions.reportUnusedTypeParameters)
        configuration.apply(\.$disablePlatformConditionalRetention, analysisOptions.disablePlatformConditionalRetention)
        configuration.apply(\.$disableUnusedImportAnalysis, analysisOptions.disableUnusedImportAnalysis)
        configuration.apply(\.$enableUnusedSystemImports, analysisOptions.enableUnusedSystemImports)
        configuration.apply(\.$superfluousIgnoreComments, analysisOptions.superfluousIgnoreComments)
        configuration.apply(\.$disableUnusedLocalizedStringAnalysis, localizedStringOptions.disableUnusedLocalizedStringAnalysis)
        configuration.apply(\.$localizedStringCatalogExclude, given(localizedStringOptions.localizedStringCatalogExclude))
        configuration.apply(\.$localizedStringKeyPatterns, given(localizedStringOptions.localizedStringKeyPatterns))
        configuration.apply(\.$localizedStringKeyLiteralMatch, localizedStringOptions.localizedStringKeyLiteralMatch)
        configuration.apply(\.$retainRuntimeLocalizedKeys, localizedStringOptions.retainRuntimeLocalizedKeys)
        configuration.apply(\.$retainUnusedImportedModules, given(retentionOptions.retainUnusedImportedModules))
        configuration.apply(\.$externalEncodableProtocols, given(retentionOptions.externalEncodableProtocols))
        configuration.apply(\.$externalCodableProtocols, given(retentionOptions.externalCodableProtocols))
        configuration.apply(\.$externalTestCaseClasses, given(retentionOptions.externalTestCaseClasses))
        configuration.apply(\.$verbose, miscellaneousOptions.verbose)
        configuration.apply(\.$quiet, miscellaneousOptions.quiet)
        configuration.apply(\.$color, miscellaneousOptions.noColor ? .never : miscellaneousOptions.color)
        configuration.apply(\.$disableUpdateCheck, miscellaneousOptions.disableUpdateCheck)
        configuration.apply(\.$strict, resultsOptions.strict)
        configuration.apply(\.$indexStorePath, given(buildOptions.indexStorePath))
        configuration.apply(\.$skipBuild, buildOptions.skipBuild)
        configuration.apply(\.$excludeTests, buildOptions.excludeTests)
        configuration.apply(\.$excludeTargets, given(buildOptions.excludeTargets))
        configuration.apply(\.$skipSchemesValidation, buildOptions.skipSchemesValidation)
        configuration.apply(\.$cleanBuild, buildOptions.cleanBuild)
        configuration.apply(\.$strictIndex, buildOptions.strictIndex)
        configuration.apply(\.$cacheMaxAgeDays, buildOptions.cacheMaxAgeDays)
        configuration.apply(\.$cacheMaxSizeGB, buildOptions.cacheMaxSizeGb)
        configuration.apply(\.$buildArguments, given(buildArguments))
        configuration.apply(\.$relativeResults, resultsOptions.relativeResults)
        configuration.apply(\.$relativeResultsBase, resultsOptions.relativeTo)
        configuration.apply(\.$changedSince, resultsOptions.changedSince)
        configuration.apply(\.$changedLines, resultsOptions.changedLines)
        configuration.apply(\.$retainCodableProperties, retentionOptions.retainCodableProperties)
        configuration.apply(\.$retainEncodableProperties, retentionOptions.retainEncodableProperties)
        configuration.apply(\.$retainEquatableProperties, retentionOptions.retainEquatableProperties)
        configuration.apply(\.$retainHashableProperties, retentionOptions.retainHashableProperties)
        configuration.apply(\.$jsonPackageManifestPath, projectOptions.jsonPackageManifestPath)
        configuration.apply(\.$baseline, baselineOptions.baseline)
        configuration.apply(\.$writeBaseline, baselineOptions.writeBaseline)
        configuration.apply(\.$pruneBaseline, baselineOptions.pruneBaseline)
        configuration.apply(\.$strictBaseline, baselineOptions.strictBaseline)
        configuration.apply(\.$writeResults, resultsOptions.writeResults)
        configuration.apply(\.$skipStdoutResults, resultsOptions.skipStdoutResults)
        configuration.apply(\.$genericProjectConfig, projectOptions.genericProjectConfig)
        configuration.apply(\.$retainSynthesizedUses, retentionOptions.retainSynthesizedUses)
        configuration.apply(\.$retainAttributes, given(retentionOptions.retainAttributes))
        configuration.apply(\.$detectUnusedAssetCatalogColors, analysisOptions.detectUnusedAssetCatalogColors)
        configuration.apply(\.$detectUnusedAssetCatalogImages, analysisOptions.detectUnusedAssetCatalogImages)
        configuration.apply(\.$detectUnusedMetalFunctions, analysisOptions.detectUnusedMetalFunctions)
    }

    func run() throws {
        let projectRoot = projectOptions.projectRoot ?? FilePath(FileManager.default.currentDirectoryPath)
        if !FileManager.default.changeCurrentDirectoryPath(projectRoot.string) {
            throw PeripheryError.changeCurrentDirectoryFailed(projectRoot)
        }

        let configuration = Configuration()

        if !projectOptions.setup {
            try configuration.load(from: projectOptions.config)
        }

        configuration.guidedSetup = projectOptions.setup
        configuration.explain = resultsOptions.explain
        configuration.summary = resultsOptions.summary
        configuration.projectRoot = projectRoot
        apply(to: configuration)

        if configuration.skipStdoutResults, configuration.writeResults == nil {
            throw PeripheryError.usageError("The '--skip-stdout-results' option requires '--write-results', otherwise the results would not be output anywhere.")
        }

        if configuration.changedLines, configuration.changedSince == nil {
            throw PeripheryError.usageError("The '--changed-lines' option requires '--changed-since', otherwise there is nothing to compare the lines with.")
        }

        configuration.buildFilenameMatchers()
        _ = try ReportExcludeRule.resolve(configuration)
        _ = try AttributeRetentionRule.resolve(configuration)
        let baseline = try ScanPreflight.validatePaths(of: configuration)

        let logger = Logger(configuration: configuration)
        ScanPreflight.applyOutputFormatRequirements(to: configuration, logger: logger)
        ScanPreflight.warnAboutIgnoredSummary(of: configuration, logger: logger)
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
            try Self.writeBaseline(.pruned(keeping: outputFilter.baselineMatchedResults, projectRoot: configuration.projectRoot), to: baselinePath)
            logger.info("Pruned \(outputFilter.staleBaselineEntries.count) stale entries from \(baselinePath.string)")
        }

        if let baselinePath = configuration.writeBaseline {
            try Self.writeBaseline(.written(from: filteredResults, union: baseline, projectRoot: configuration.projectRoot), to: baselinePath)
        }

        let reportedResults = try ChangedSinceFilter(configuration: configuration, shell: shell, logger: logger).filter(filteredResults)

        let outputFormat = configuration.outputFormat
        let formatter = outputFormat.formatter.init(configuration: configuration, logger: logger)
        let colored = outputFormat.supportsColoredOutput && logger.isColoredOutputEnabled

        let printsToStdout = Self.shouldPrintToStdout(configuration: configuration, resultCount: filteredResults.count)
        let summaryPlacement = Self.summaryPlacement(configuration: configuration, printsToStdout: printsToStdout, resultCount: reportedResults.count)
        let summary = summaryPlacement == .none ? nil : formatter.summarize(reportedResults)
        let reportSummary = summaryPlacement == .inReport ? summary : nil

        let formattedOutput = try formatter.format(reportedResults, summary: reportSummary, colored: colored)

        if let output = formattedOutput, printsToStdout {
            if outputFormat.supportsAuxiliaryOutput {
                logger.info("", canQuiet: true)
            }

            logger.output(output)

            if summaryPlacement == .afterResults, let summary {
                logger.info("", canQuiet: true)
                logger.info(formatter.describe(summary, colored: colored), canQuiet: true)
            }
        }

        if let resultsPath = configuration.writeResults {
            let output: String = if colored {
                // The formatted output contains ANSI escape codes, so we need to re-format
                // with coloring disabled.
                try formatter.format(reportedResults, summary: reportSummary, colored: false) ?? ""
            } else {
                formattedOutput ?? ""
            }

            try output.write(to: resultsPath.url, atomically: true, encoding: .utf8)
        }

        logger.endInterval(interval)

        updateChecker.notifyIfAvailable()

        if !reportedResults.isEmpty, configuration.strict {
            throw PeripheryError.foundIssues(count: reportedResults.count)
        }

        if let failure = Self.staleBaselineFailure(configuration: configuration, staleEntryCount: outputFilter.staleBaselineEntries.count) {
            throw failure
        }
    }

    /// The error that ends the scan with a non-zero status when `--strict-baseline` finds stale entries, which
    /// `--prune-baseline` has just removed.
    /// With `--quiet`, stdout stays empty when there is nothing to report, and the report goes to
    /// the `--write-results` file only.
    static func shouldPrintToStdout(configuration: Configuration, resultCount: Int) -> Bool {
        if configuration.skipStdoutResults {
            return false
        }
        if configuration.quiet, configuration.writeResults != nil || resultCount == 0 {
            return false
        }
        return true
    }

    enum SummaryPlacement {
        case none
        /// Text printed after the results on stdout, never written to the `--write-results` file.
        case afterResults
        /// Part of the report, on stdout and in the `--write-results` file.
        case inReport
    }

    /// The summary follows the results of the `xcode` format unless `--no-summary` is given, and is part of the
    /// `json` report only with `--summary`. The other formats never have one, so that their parsers are unaffected.
    /// The text summary needs results printed on stdout, and is silenced by `--quiet` like every other message.
    static func summaryPlacement(configuration: Configuration, printsToStdout: Bool, resultCount: Int) -> SummaryPlacement {
        switch configuration.outputFormat {
        case .xcode:
            let enabled = configuration.summary ?? true
            return enabled && printsToStdout && resultCount > 0 && !configuration.quiet ? .afterResults : .none
        case .json:
            return configuration.summary == true ? .inReport : .none
        default:
            return .none
        }
    }

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
}

extension OutputFormat: ArgumentParser.ExpressibleByArgument {}
extension ColorOption: ArgumentParser.ExpressibleByArgument {}

extension FilePath: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}
