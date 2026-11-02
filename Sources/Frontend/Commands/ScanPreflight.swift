import Configuration
import Foundation
import Logger
import PeripheryKit
import Shared
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

    /// Checks the baseline and the output destinations, and returns the decoded baseline for filtering.
    static func validatePaths(of configuration: Configuration) throws -> Baseline? {
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

        let data: Data
        do {
            data = try Data(contentsOf: normalized.url)
        } catch {
            throw unreadable(path, reason: error.localizedDescription)
        }

        do {
            return try JSONDecoder().decode(Baseline.self, from: data)
        } catch {
            throw PeripheryError.usageError("--baseline: '\(path.string)' is not a Periphery baseline (expected {\"v1\": {\"usrs\": [...]}})")
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
