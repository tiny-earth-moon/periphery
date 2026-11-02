import Configuration
import FilenameMatcher
import Foundation
import Logger
import SystemPackage

public final class OutputDeclarationFilter {
    private let configuration: Configuration
    private let logger: Logger
    private let contextualLogger: ContextualLogger

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

            declarations = declarations.filter {
                guard let match = matcher.match($0) else { return true }

                didFilterDeclaration = true
                didMatchLegacyId = didMatchLegacyId || match == .legacy
                return false
            }

            if !didFilterDeclaration {
                logger.warn("No results were filtered by the baseline.")
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
