import Foundation
import Logger

/// A format whose report can hold the summary.
protocol SummaryFormatter: OutputFormatter {
    func format(_ results: [ScanResult], summary: ScanSummary, colored: Bool) throws -> String?
}

public extension OutputFormatter {
    func summarize(_ results: [ScanResult]) -> ScanSummary {
        ScanSummaryBuilder(logger: logger).build(results) { describe($0) }
    }

    /// The report with the summary, for the formats that hold one (`json`); the other formats ignore it.
    func format(_ results: [ScanResult], summary: ScanSummary?, colored: Bool) throws -> String? {
        if let summary, let formatter = self as? SummaryFormatter {
            return try formatter.format(results, summary: summary, colored: colored)
        }

        return try format(results, colored: colored)
    }

    /// The summary as text, printed after the results.
    func describe(_ summary: ScanSummary, colored: Bool) -> String {
        let asterisk = colored ? logger.colorize("*", .boldGreen) : "*"
        let counts = summary.countsByAnnotation
            .sorted { ($1.value, $0.key) < ($0.value, $1.key) }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")

        var lines = [
            "\(asterisk) Summary: \(counted(summary.resultCount, "result")) (\(counts))",
            "\(asterisk) Removable lines (estimate): \(summary.removableLineCount)",
            "\(asterisk) Files entirely unused: \(summary.unusedFiles.count)",
        ]
        lines += summary.unusedFiles.map { "  \(outputPath($0.path).string) (\(counted($0.lineCount, "line")))" }

        return lines.joined(separator: "\n")
    }
}

extension OutputFormatter {
    func summaryObject(_ summary: ScanSummary) -> [AnyHashable: Any] {
        [
            "total": summary.resultCount,
            "counts": summary.countsByAnnotation,
            "removableLines": summary.removableLineCount,
            "unusedFiles": summary.unusedFiles.map { ["path": outputPath($0.path).string, "lines": $0.lineCount] },
        ]
    }

    private func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
