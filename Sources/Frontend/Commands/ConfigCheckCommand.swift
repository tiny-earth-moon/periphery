import ArgumentParser
import Configuration
import Foundation
import Logger
import PeripheryKit
import Shared
import SourceGraph
import SystemPackage

struct ConfigCheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check the configuration file without scanning: unknown keys, values of the wrong type, invalid 'report_exclude' and 'retain_attributes' entries, baseline and output paths. Exits with status 1 on any problem"
    )

    @Option(help: "Path to the root directory of your project")
    var projectRoot: FilePath = .init(FileManager.default.currentDirectoryPath)

    @Option(help: "Path to configuration file, relative paths being resolved from '--project-root'. By default outskirts looks for .outskirts.yml (or .periphery.yml) in the project root")
    var config: FilePath?

    func run() throws {
        if !FileManager.default.changeCurrentDirectoryPath(projectRoot.string) {
            throw PeripheryError.changeCurrentDirectoryFailed(projectRoot)
        }

        let configuration = Configuration()

        guard let path = try configuration.configurationPath(withUserProvided: config) else {
            let names = Configuration.configurationFileNames.joined(separator: ", ")
            throw PeripheryError.usageError("No configuration file in '\(projectRoot.string)' (looked for \(names)), pass one with '--config'.")
        }

        let logger = Logger(quiet: false, verbose: false, colorMode: .auto, messagesToStderr: true)
        var warnings: [String] = []
        try configuration.load(from: path) { warnings.append($0) }
        let errors = Self.errors(in: configuration)

        warnings.forEach { logger.warn($0) }
        errors.forEach { logger.error($0) }

        let count = warnings.count + errors.count

        guard count > 0 else {
            print("\(path.string): ok")
            return
        }

        logger.error("\(path.string): \(count) \(count > 1 ? "problems" : "problem") found")
        throw ExitCode.failure
    }

    // MARK: - Private

    /// The checks a scan makes on the loaded configuration before building, each stopping the scan with its error.
    private static func errors(in configuration: Configuration) -> [String] {
        let checks: [() throws -> Void] = [
            { _ = try ReportExcludeRule.resolve(configuration) },
            { _ = try AttributeRetentionRule.resolve(configuration) },
            { _ = try ScanPreflight.validatePaths(of: configuration) },
        ]

        return checks.compactMap { check in
            do {
                try check()
                return nil
            } catch {
                return "\(error)"
            }
        }
    }
}
