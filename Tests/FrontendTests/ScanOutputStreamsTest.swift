import Foundation
import XCTest

/// Runs the `periphery` executable on a small package and checks which stream carries what.
final class ScanOutputStreamsTest: XCTestCase {
    private static let package: Result<URL, Error> = Result {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("periphery-streams-\(UUID().uuidString)")
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
            .appendingPathComponent("periphery-streams-output-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        addTeardownBlock { [outputDirectory] in
            if let outputDirectory {
                try? FileManager.default.removeItem(at: outputDirectory)
            }
        }
    }

    func testVerboseLogsGoToStderrSoThatJsonOnStdoutStaysParseable() throws {
        let output = try scan(["--format", "json", "--verbose"])

        XCTAssertEqual(output.status, 0, output.stderrText)
        XCTAssertTrue(try reportNames(in: output.stdout).contains("UnusedFixtureType"), output.stdoutText)
        XCTAssertTrue(output.stderrText.contains("[version]"), "verbose messages are expected on stderr:\n\(output.stderrText)")
    }

    func testSkipStdoutResultsWithWriteResultsPrintsNothingToStdout() throws {
        let report = outputDirectory.appendingPathComponent("report.json")

        let output = try scan(["--format", "json", "--verbose", "--write-results", report.path, "--skip-stdout-results"])

        XCTAssertEqual(output.status, 0, output.stderrText)
        XCTAssertEqual(output.stdoutText, "")
        XCTAssertTrue(try reportNames(in: Data(contentsOf: report)).contains("UnusedFixtureType"))
        XCTAssertTrue(output.stderrText.contains("[version]"), "verbose messages are expected on stderr:\n\(output.stderrText)")
    }

    func testWriteResultsAloneStillPrintsTheResultsToStdout() throws {
        let report = outputDirectory.appendingPathComponent("report.json")

        let output = try scan(["--format", "json", "--write-results", report.path])

        XCTAssertEqual(output.status, 0, output.stderrText)
        XCTAssertTrue(try reportNames(in: output.stdout).contains("UnusedFixtureType"), output.stdoutText)
        XCTAssertTrue(try reportNames(in: Data(contentsOf: report)).contains("UnusedFixtureType"))
    }

    func testSkipStdoutResultsWithoutWriteResultsIsAUsageError() throws {
        let output = try scan(["--format", "json", "--skip-stdout-results"])

        XCTAssertNotEqual(output.status, 0)
        XCTAssertEqual(output.stdoutText, "")
        XCTAssertTrue(output.stderrText.contains("--write-results"), output.stderrText)
    }

    func testXcodeFormatKeepsProgressAndVerboseMessagesOnStdout() throws {
        let output = try scan(["--format", "xcode", "--verbose"])

        XCTAssertEqual(output.status, 0, output.stderrText)
        XCTAssertTrue(output.stdoutText.contains("[version]"), output.stdoutText)
        XCTAssertTrue(output.stdoutText.contains("UnusedFixtureType"), output.stdoutText)
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

    private func reportNames(in data: Data) throws -> [String] {
        let report = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]], "stdout is not a JSON report")
        return report.compactMap { $0["name"] as? String }
    }

    private func scan(_ arguments: [String]) throws -> ScanOutput {
        let package = try Self.package.get()
        let stdoutFile = outputDirectory.appendingPathComponent("stdout.txt")
        let stderrFile = outputDirectory.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: stdoutFile.path, contents: nil)
        FileManager.default.createFile(atPath: stderrFile.path, contents: nil)

        let exited = DispatchSemaphore(value: 0)
        let process = Process()
        process.executableURL = try peripheryExecutable()
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

    private func peripheryExecutable() throws -> URL {
        #if os(macOS)
            let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        #else
            let products = Bundle.main.bundleURL.deletingLastPathComponent()
        #endif
        let url = products.appendingPathComponent("periphery")
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path, NSLocalizedDescriptionKey: "Build the 'periphery' product before running this test"])
        }

        return url
    }
}
