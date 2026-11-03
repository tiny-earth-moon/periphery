import Configuration
import FilenameMatcher
import Foundation
import Logger
import SystemPackage

public final class OutputDeclarationFilter {
    private let configuration: Configuration
    private let logger: Logger
    private let contextualLogger: ContextualLogger

    /// The baseline entries that no result matched in the last call to ``filter(_:with:)``, sorted.
    public private(set) var staleBaselineEntries: [String] = []

    /// The results that the baseline matched in the last call to ``filter(_:with:)``, before `report_include` and
    /// `report_exclude` were applied.
    public private(set) var baselineMatchedResults: [ScanResult] = []

    public required init(configuration: Configuration, logger: Logger) {
        self.configuration = configuration
        self.logger = logger
        contextualLogger = logger.contextualized(with: "report:filter")
    }

    public func filter(_ declarations: [ScanResult], with baseline: Baseline?) throws -> [ScanResult] {
        var declarations = declarations

        if let baseline {
            let matcher = BaselineMatcher(baseline, projectRoot: configuration.projectRoot)
            var didFilterDeclaration = false
            var didMatchLegacyId = false
            var matchedEntries: Set<String> = []
            var matchedResults: [ScanResult] = []

            declarations = declarations.filter {
                guard let match = matcher.match($0) else { return true }

                didFilterDeclaration = true
                matchedEntries.formUnion(matcher.entries(matchedBy: $0))
                matchedResults.append($0)
                didMatchLegacyId = didMatchLegacyId || match == .legacy
                return false
            }

            if !didFilterDeclaration {
                logger.warn("No results were filtered by the baseline.")
            }

            baselineMatchedResults = matchedResults
            staleBaselineEntries = matcher.staleEntries(given: matchedEntries)

            if !staleBaselineEntries.isEmpty {
                let count = staleBaselineEntries.count
                logger.info(count == 1 ? "1 baseline entry no longer matches any result" : "\(count) baseline entries no longer match any result", canQuiet: false)

                for entry in staleBaselineEntries {
                    logger.debug("Stale baseline entry: \(entry)")
                }
            }

            if didMatchLegacyId {
                logger.warn("The baseline holds ids written by an earlier version, which change when lines move or the project is checked out elsewhere. Rewrite it with '--write-baseline' (without '--baseline') to switch to stable ids.")
            }
        }

        if configuration.reportInclude.isEmpty, configuration.reportExclude.isEmpty {
            return declarations.sorted { $0.declaration < $1.declaration }
        }

        let reportExcludeRules = try ReportExcludeRule.resolve(configuration)

        return declarations
            .filter { [contextualLogger] result in
                var path = result.declaration.location.file.path

                // If the declaration has a location override, use it as the path for filtering.
                if let override = result.declaration.commentCommands.locationOverride {
                    let (overridePath, _, _) = override
                    path = overridePath
                }

                if configuration.reportIncludeMatchers.isEmpty {
                    if reportExcludeRules.contains(where: { $0.excludes(result, path: path.string) }) {
                        contextualLogger.debug("Excluding \(path)")
                        return false
                    }

                    return true
                }

                if configuration.reportIncludeMatchers.anyMatch(filename: path.string) {
                    contextualLogger.debug("Including \(path)")
                    return true
                }

                return false
            }
            .sorted { $0.declaration < $1.declaration }
    }
}
