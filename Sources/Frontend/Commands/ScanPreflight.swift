import Configuration
import Foundation
import Logger
import PeripheryKit
import Shared
import SourceGraph
import SystemPackage

/// Checks and adjustments applied to the configuration before the scan starts, so that a mistake costs
/// no build, indexing or analysis.
enum ScanPreflight {
    /// Forces `relativeResults` for the output formats that only work with paths relative to the project root.
    static func applyOutputFormatRequirements(to configuration: Configuration, logger: Logger) {
        guard configuration.outputFormat.requiresRelativePaths, !configuration.relativeResults else { return }

        configuration.relativeResults = true
        logger.contextualized(with: "configuration").debug("'\(configuration.outputFormat.rawValue)' output requires relative paths, enabling '--relative-results'")
    }

    /// Warns that `--summary` has no effect with a format that never holds a summary, which keeps its output unchanged.
    static func warnAboutIgnoredSummary(of configuration: Configuration, logger: Logger) {
        guard configuration.summary == true, ![.xcode, .json].contains(configuration.outputFormat) else { return }

        logger.warn("The '--summary' option has no effect with the '\(configuration.outputFormat.rawValue)' format, only with 'xcode' and 'json'.")
    }

    /// Runs every check a scan makes on the configuration before building, stopping at the first failure, and returns
    /// the decoded baseline for filtering.
    static func validate(_ configuration: Configuration) throws -> Baseline? {
        for check in optionChecks(of: configuration) {
            try check()
        }
        return try validatePaths(of: configuration)
    }

    /// The messages of every check `validate(_:)` makes, each check reporting independently of the others.
    static func problems(in configuration: Configuration) -> [String] {
        let checks = optionChecks(of: configuration) + [{ _ = try validatePaths(of: configuration) }]

        return checks.compactMap { check in
            do {
                try check()
                return nil
            } catch {
                return "\(error)"
            }
        }
    }

    /// Checks the baseline and the output destinations, and returns the decoded baseline for filtering.
    static func validatePaths(of configuration: Configuration) throws -> Baseline? {
        try validateBaselineOptions(of: configuration)

        let baseline = try configuration.baseline.map { try loadBaseline(at: $0) }

        if let path = configuration.writeBaseline {
            try validateOutput(path, option: "--write-baseline")
        }

        if let path = configuration.writeResults {
            try validateOutput(path, option: "--write-results")
        }

        return baseline
    }

    // MARK: - Private

    private static func optionChecks(of configuration: Configuration) -> [() throws -> Void] {
        [
            {
                if configuration.skipStdoutResults, configuration.writeResults == nil {
                    throw PeripheryError.usageError("The '--skip-stdout-results' option requires '--write-results', otherwise the results would not be output anywhere.")
                }
            },
            {
                if configuration.changedLines, configuration.changedSince == nil {
                    throw PeripheryError.usageError("The '--changed-lines' option requires '--changed-since', otherwise there is nothing to compare the lines with.")
                }
            },
            { _ = try ReportExcludeRule.resolve(configuration) },
            { _ = try AttributeRetentionRule.resolve(configuration) },
        ]
    }

    private static func validateBaselineOptions(of configuration: Configuration) throws {
        if configuration.strictBaseline, configuration.baseline == nil {
            throw PeripheryError.usageError("The '--strict-baseline' option requires '--baseline', the file to check.")
        }

        if configuration.pruneBaseline {
            guard configuration.baseline != nil else {
                throw PeripheryError.usageError("The '--prune-baseline' option requires '--baseline', the file to prune.")
            }
            guard configuration.writeBaseline == nil else {
                throw PeripheryError.usageError("The '--prune-baseline' option rewrites the file given to '--baseline', it cannot be combined with '--write-baseline'.")
            }
        }
    }

    private static func loadBaseline(at path: FilePath) throws -> Baseline {
        let normalized = path.lexicallyNormalized()
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: normalized.string, isDirectory: &isDirectory) else {
            throw unreadable(path, reason: "no such file")
        }
        guard !isDirectory.boolValue else {
            throw unreadable(path, reason: "is a directory")
        }
        guard FileManager.default.isReadableFile(atPath: normalized.string) else {
            throw unreadable(path, reason: "permission denied")
        }

        do {
            return try Baseline.load(from: path)
        } catch let error as PeripheryError {
            throw error
        } catch {
            throw unreadable(path, reason: error.localizedDescription)
        }
    }

    private static func unreadable(_ path: FilePath, reason: String) -> PeripheryError {
        .usageError("--baseline: '\(path.string)' cannot be read (\(reason))")
    }

    private static func validateOutput(_ path: FilePath, option: String) throws {
        let normalized = path.lexicallyNormalized()
        let parent = normalized.removingLastComponent()
        let directory = parent.isEmpty ? "." : parent.string
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: normalized.string, isDirectory: &isDirectory), isDirectory.boolValue {
            throw PeripheryError.usageError("\(option): '\(path.string)' is a directory")
        }

        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory) else {
            throw PeripheryError.usageError("\(option): directory '\(directory)' does not exist")
        }
        guard isDirectory.boolValue else {
            throw PeripheryError.usageError("\(option): directory '\(directory)' is not a directory")
        }
        guard FileManager.default.isWritableFile(atPath: directory) else {
            throw PeripheryError.usageError("\(option): directory '\(directory)' is not writable")
        }
    }
}
