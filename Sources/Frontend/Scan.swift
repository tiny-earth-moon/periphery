import Configuration
import Foundation
import Indexer
import Logger
import PeripheryKit
import ProjectDrivers
import Shared
import SourceGraph
import SystemPackage

final class Scan {
    private let configuration: Configuration
    private let logger: Logger
    private let graph: SourceGraph
    private let swiftVersion: SwiftVersion

    required init(configuration: Configuration, logger: Logger, swiftVersion: SwiftVersion) {
        self.configuration = configuration
        self.logger = logger
        self.swiftVersion = swiftVersion
        graph = SourceGraph(configuration: configuration, logger: logger)
    }

    struct Output {
        let results: [ScanResult]
        /// When the newest index store unit of each source file was written.
        let unitDates: [FilePath: Date]
        /// The driver that built the project, so that `fix --verify` rebuilds it the same way.
        let driver: ProjectDriver
    }

    func perform(project: Project) throws -> Output {
        if !configuration.indexStorePath.isEmpty {
            logger.warn("When using the '--index-store-path' option please ensure that Xcode is not running. False-positives can occur if Xcode writes to the index store while outskirts is running.")

            if !configuration.skipBuild {
                logger.warn("The '--index-store-path' option implies '--skip-build', specify it to silence this warning.")
                configuration.skipBuild = true
            }
        }

        let driver = try setup(project)

        // Output configuration after project setup as the driver may alter it.
        if configuration.verbose {
            let configYaml = try configuration.asYaml()
            logger.debug("[configuration:begin]\n\(configYaml.trimmed)\n[configuration:end]")
        }

        try build(driver)
        let (indexStoreSwiftVersion, unitDates) = try index(driver)
        try analyze(swiftVersion: indexStoreSwiftVersion)
        explain()
        return Output(results: buildResults(), unitDates: unitDates, driver: driver)
    }

    // MARK: - Private

    private func setup(_ project: Project) throws -> ProjectDriver {
        let driverSetupInterval = logger.beginInterval("driver:setup")
        let driver = try project.driver()
        logger.endInterval(driverSetupInterval)
        return driver
    }

    private func build(_ driver: ProjectDriver) throws {
        let driverBuildInterval = logger.beginInterval("driver:build")
        try driver.build()
        logger.endInterval(driverBuildInterval)
    }

    /// Returns the Swift version whose toolchain workarounds the analysis applies, resolved from the index store, and
    /// when the newest unit of each source file was written.
    private func index(_ driver: ProjectDriver) throws -> (SwiftVersion, [FilePath: Date]) {
        let indexInterval = logger.beginInterval("index")

        if configuration.outputFormat.supportsAuxiliaryOutput {
            let asterisk = logger.colorize("*", .boldGreen)
            logger.info("\(asterisk) Indexing...")
        }

        let indexLogger = logger.contextualized(with: "index")
        let plan = try driver.plan(logger: indexLogger)
        let graphMutex = SourceGraphMutex(graph: graph)
        let pipeline = IndexPipeline(plan: plan, graph: graphMutex, logger: indexLogger, configuration: configuration, swiftVersion: swiftVersion)
        try pipeline.perform()
        logger.endInterval(indexInterval)

        // Workarounds applied to the whole graph cannot tell which unit a declaration came from, so they follow the
        // oldest compiler that produced any unit.
        let indexStoreSwiftVersion = swiftVersion.producingIndexUnits(
            withProviderVersions: plan.unitProviderVersions,
            logger: indexLogger,
            context: "index store"
        )
        indexLogger.debug("Toolchain workarounds gated on Swift \(indexStoreSwiftVersion.indexStoreVersion)")

        let unitDates = plan.sourceFiles.reduce(into: [FilePath: Date]()) { result, entry in
            if let newest = entry.value.compactMap(\.modificationDate).max() {
                result[entry.key.path] = newest
            }
        }
        return (indexStoreSwiftVersion, unitDates)
    }

    private func analyze(swiftVersion: SwiftVersion) throws {
        let analyzeInterval = logger.beginInterval("analyze")

        if configuration.outputFormat.supportsAuxiliaryOutput {
            let asterisk = logger.colorize("*", .boldGreen)
            logger.info("\(asterisk) Analyzing...")
        }

        try SourceGraphMutatorRunner(
            graph: graph,
            logger: logger,
            configuration: configuration,
            swiftVersion: swiftVersion
        ).perform()
        logger.endInterval(analyzeInterval)
    }

    /// Prints the explanations asked with `--explain`, before the results.
    private func explain() {
        guard !configuration.explain.isEmpty else { return }

        let explanation = DeclarationExplainer(graph: graph, configuration: configuration).explain(configuration.explain)
        logger.info("", canQuiet: false)
        logger.info(explanation, canQuiet: false)
    }

    private func buildResults() -> [ScanResult] {
        let resultInterval = logger.beginInterval("result:build")
        let results = ScanResultBuilder.build(for: graph, configuration: configuration)
        logger.endInterval(resultInterval)
        return results
    }
}
