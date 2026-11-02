import Configuration
import Foundation
import Logger
import SourceGraph
import SystemPackage

final class GitHubActionsFormatter: OutputFormatter {
    static let requiresRelativePaths = true

    let configuration: Configuration
    let logger: Logger
    lazy var currentFilePath: FilePath = .current

    init(configuration: Configuration, logger: Logger) {
        self.logger = logger
        self.configuration = configuration
    }

    func format(_ results: [ScanResult], colored: Bool) throws -> String? {
        guard !results.isEmpty else { return nil }

        return results.flatMap { result in
            describe(result, colored: colored).map { location, description in
                prefix(for: location, result: result) + escapeData(description)
            }
        }
        .joined(separator: "\n")
    }

    // MARK: - Private

    private func prefix(for location: Location, result: ScanResult) -> String {
        let path = outputPath(location)
        let lineNum = String(location.line)
        let column = location.column
        let title = describe(result.annotation)

        return "::warning file=\(escapeProperty(path.string)),line=\(lineNum),col=\(column),title=\(escapeProperty(title))::"
    }

    /// Escapes the message part of a workflow command.
    private func escapeData(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "\r", with: "%0D")
            .replacingOccurrences(of: "\n", with: "%0A")
    }

    /// Escapes a property value of a workflow command, which additionally treats `,` and `:` as delimiters.
    private func escapeProperty(_ value: String) -> String {
        escapeData(value)
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ",", with: "%2C")
    }
}
