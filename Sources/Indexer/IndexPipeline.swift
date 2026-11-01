import Configuration
import Foundation
import Logger
import Shared
import SourceGraph

public struct IndexPipeline {
    /// The global accent color of Xcode's app templates, assumed when no build setting names it.
    static let defaultGlobalAccentColorName = "AccentColor"

    private let plan: IndexPlan
    private let graph: SourceGraphMutex
    private let logger: ContextualLogger
    private let configuration: Configuration
    private let swiftVersion: SwiftVersion

    public init(plan: IndexPlan, graph: SourceGraphMutex, logger: ContextualLogger, configuration: Configuration, swiftVersion: SwiftVersion) {
        self.plan = plan
        self.graph = graph
        self.logger = logger
        self.configuration = configuration
        self.swiftVersion = swiftVersion
    }

    public func perform() throws -> Int {
        try IndexCoverage(plan: plan, logger: logger, configuration: configuration).verify()

        // Generated String Catalog symbols are mapped to their keys rather than indexed as source.
        let generatedStringSymbolFiles = plan.sourceFiles.filter { configuration.isAnalyzedGeneratedStringSymbolsFile($0.key.path) }
        let scannedLOC = try SwiftIndexer(
            sourceFiles: plan.sourceFiles.filter { generatedStringSymbolFiles[$0.key] == nil },
            graph: graph,
            logger: logger,
            configuration: configuration,
            swiftVersion: swiftVersion
        ).perform()

        if !plan.plistPaths.isEmpty {
            try InfoPlistIndexer(
                infoPlistFiles: plan.plistPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xibPaths.isEmpty {
            try XibIndexer(
                xibFiles: plan.xibPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xcDataModelPaths.isEmpty {
            try XCDataModelIndexer(
                files: plan.xcDataModelPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xcMappingModelPaths.isEmpty {
            try XCMappingModelIndexer(
                files: plan.xcMappingModelPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xcStringsPaths.isEmpty, !configuration.disableUnusedLocalizedStringAnalysis {
            try GeneratedStringSymbolsIndexer(files: generatedStringSymbolFiles, graph: graph, logger: logger).perform()
            try XCStringsIndexer(
                files: plan.xcStringsPaths,
                modulesByFile: plan.xcStringsModules,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if configuration.detectsUnusedAssetCatalogSymbols {
            let accentColorNames = plan.globalAccentColorNames.flatMap { $0.isEmpty ? nil : $0 } ?? [Self.defaultGlobalAccentColorName]
            graph.withLock { $0.addAssetCatalogNameReferences(accentColorNames) }
        }

        graph.withLock { $0.indexingComplete() }
        return scannedLOC
    }
}
