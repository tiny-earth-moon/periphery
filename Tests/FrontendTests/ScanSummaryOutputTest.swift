import Configuration
import Foundation
@testable import Frontend
@testable import TestShared
import XCTest

/// Runs the `outskirts` executable on a small package and checks where the summary goes, and that turning it off
/// leaves the report as it was.
final class ScanSummaryOutputTest: XCTestCase {
    private static let package: Result<URL, Error> = Result {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("periphery-summary-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources/Fixture")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try """
        // swift-tools-version:5.9
        import PackageDescription
        let package = Package(name: "Fixture", targets: [.target(name: "Fixture")])
        """.write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "struct UnusedFixtureType {}\n".write(to: sources.appendingPathComponent("Fixture.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private static let expectedTextSummary = """
    * Summary: 1 result (unused: 1)
    * Unused lines (estimate): 1
    * Files entirely unused: 1
      Sources/Fixture/Fixture.swift (1 line)

    """

    private var outputDirectory: URL!

    // swiftlint:disable:next static_over_final_class
    override class func tearDown() {
        if let package = try? package.get() {
            try? FileManager.default.removeItem(at: package)
        }

        super.tearDown()
    }

    override func setUpWithError() throws {
        outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("periphery-summary-output-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        addTeardownBlock { [outputDirectory] in
            if let outputDirectory {
                try? FileManager.default.removeItem(at: outputDirectory)
            }
        }
    }

    func testXcodeFormatPrintsTheSummaryAfterTheResults_andNoSummaryLeavesOnlyTheResults() throws {
        let report = outputDirectory.appendingPathComponent("report.txt")

        let withSummary = try scan(["--format", "xcode", "--relative-results", "--write-results", report.path])
        let withoutSummary = try scan(["--format", "xcode", "--relative-results", "--no-summary"])

        XCTAssertEqual(withSummary.status, 0, withSummary.stderrText)
        XCTAssertEqual(withoutSummary.status, 0, withoutSummary.stderrText)
        XCTAssertTrue(withSummary.stdoutText.hasSuffix("warning: Unused struct 'UnusedFixtureType'\n\n" + Self.expectedTextSummary), withSummary.stdoutText)
        XCTAssertTrue(withoutSummary.stdoutText.hasSuffix("warning: Unused struct 'UnusedFixtureType'\n"), withoutSummary.stdoutText)
        XCTAssertEqual(warnings(in: withSummary.stdoutText), warnings(in: withoutSummary.stdoutText))
        XCTAssertEqual(try String(contentsOf: report, encoding: .utf8), "Sources/Fixture/Fixture.swift:1:8: warning: Unused struct 'UnusedFixtureType'")
    }

    func testJsonFormatHoldsASummaryObjectOnlyWithSummary() throws {
        let plain = try scan(["--format", "json", "--relative-results"])
        let withSummary = try scan(["--format", "json", "--relative-results", "--summary"])

        XCTAssertNotNil(try JSONSerialization.jsonObject(with: plain.stdout) as? [[String: Any]], plain.stdoutText)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: withSummary.stdout) as? [String: Any], withSummary.stdoutText)
        XCTAssertEqual(object["results"] as? NSArray, try JSONSerialization.jsonObject(with: plain.stdout) as? NSArray)
        XCTAssertEqual(object["summary"] as? NSDictionary, [
            "total": 1,
            "counts": ["unused": 1],
            "unusedLines": 1,
            "unusedFiles": [["path": "Sources/Fixture/Fixture.swift", "lines": 1]],
        ] as NSDictionary)
    }

    func testSummaryPlacementFollowsTheFormatAndTheOptions() {
        XCTAssertEqual(placement(.xcode), .afterResults)
        XCTAssertEqual(placement(.xcode, summary: false), .none)
        XCTAssertEqual(placement(.xcode, quiet: true), .none)
        XCTAssertEqual(placement(.xcode, printsToStdout: false), .none)
        XCTAssertEqual(placement(.xcode, resultCount: 0), .none)
        XCTAssertEqual(placement(.json), .none)
        XCTAssertEqual(placement(.json, summary: true), .inReport)
        XCTAssertEqual(placement(.json, summary: true, quiet: true, printsToStdout: false), .inReport)

        for format in OutputFormat.allCases where ![.xcode, .json].contains(format) {
            XCTAssertEqual(placement(format, summary: true), .none, "\(format)")
        }
    }

    // MARK: - Private

    private struct ScanOutput {
        let status: Int32
        let stdout: Data
        let stderr: Data

        var stdoutText: String {
            String(bytes: stdout, encoding: .utf8) ?? ""
        }

        var stderrText: String {
            String(bytes: stderr, encoding: .utf8) ?? ""
        }
    }

    private func placement(
        _ format: OutputFormat,
        summary: Bool? = nil,
        quiet: Bool = false,
        printsToStdout: Bool = true,
        resultCount: Int = 1
    ) -> ScanCommand.SummaryPlacement {
        let configuration = Configuration()
        configuration.outputFormat = format
        configuration.summary = summary
        configuration.quiet = quiet
        return ScanCommand.summaryPlacement(configuration: configuration, printsToStdout: printsToStdout, resultCount: resultCount)
    }

    private func warnings(in output: String) -> [Substring] {
        output.split(separator: "\n").filter { $0.contains("warning:") }
    }

    private func scan(_ arguments: [String]) throws -> ScanOutput {
        let package = try Self.package.get()
        let stdoutFile = outputDirectory.appendingPathComponent("stdout.txt")
        let stderrFile = outputDirectory.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: stdoutFile.path, contents: nil)
        FileManager.default.createFile(atPath: stderrFile.path, contents: nil)

        let exited = DispatchSemaphore(value: 0)
        let process = Process()
        process.executableURL = try locatePeripheryExecutable(near: Self.self)
        process.arguments = ["scan", "--disable-update-check"] + arguments
        process.currentDirectoryURL = package
        process.standardOutput = try FileHandle(forWritingTo: stdoutFile)
        process.standardError = try FileHandle(forWritingTo: stderrFile)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()

        if exited.wait(timeout: .now() + 300) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            XCTFail("periphery did not exit within 300s")
        }

        return try ScanOutput(
            status: process.terminationStatus,
            stdout: Data(contentsOf: stdoutFile),
            stderr: Data(contentsOf: stderrFile)
        )
    }
}
