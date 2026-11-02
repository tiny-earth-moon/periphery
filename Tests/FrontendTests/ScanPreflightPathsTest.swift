import ArgumentParser
import Configuration
import Foundation
@testable import Frontend
import PeripheryKit
import Shared
import SystemPackage
import XCTest

final class ScanPreflightPathsTest: XCTestCase {
    private var directory: FilePath!
    private var originalDirectory: String!

    override func setUpWithError() throws {
        originalDirectory = FileManager.default.currentDirectoryPath
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-preflight-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // Resolve symlinks (/var -> /private/var) so that the paths match the ones the process reports.
        directory = FilePath(url.resolvingSymlinksInPath().path)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(originalDirectory)
        // Restore permissions that a test removed, so that the cleanup succeeds.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.appending("readonly").string)
        try FileManager.default.removeItem(atPath: directory.string)
    }

    // MARK: - Helpers

    private func configuration(
        baseline: FilePath? = nil,
        writeBaseline: FilePath? = nil,
        writeResults: FilePath? = nil
    ) -> Configuration {
        let configuration = Configuration()
        configuration.baseline = baseline
        configuration.writeBaseline = writeBaseline
        configuration.writeResults = writeResults
        return configuration
    }

    private func message(of configuration: Configuration, file: StaticString = #filePath, line: UInt = #line) -> String? {
        do {
            _ = try ScanPreflight.validatePaths(of: configuration)
            XCTFail("Expected an error", file: file, line: line)
            return nil
        } catch {
            XCTAssertTrue(error is PeripheryError, "\(error)", file: file, line: line)
            return (error as? PeripheryError)?.errorDescription
        }
    }

    private func write(_ contents: String, to name: String) throws -> FilePath {
        let path = directory.appending(name)
        try contents.write(toFile: path.string, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Baseline

    func testBaseline_missingFile_namesTheOptionAndTheReason() {
        let path = directory.appending("missing.json")

        XCTAssertEqual(
            message(of: configuration(baseline: path)),
            "--baseline: '\(path.string)' cannot be read (no such file)"
        )
    }

    func testBaseline_directory_isRejected() {
        XCTAssertEqual(
            message(of: configuration(baseline: directory)),
            "--baseline: '\(directory.string)' cannot be read (is a directory)"
        )
    }

    func testBaseline_wrongShape_isRejectedAsNotABaseline() throws {
        let path = try write(#"{"x":1}"#, to: "bad.json")

        XCTAssertEqual(
            message(of: configuration(baseline: path)),
            #"--baseline: '\#(path.string)' is not a Periphery baseline (expected {"v1": {"usrs": [...]}})"#
        )
    }

    func testBaseline_notJSON_isRejectedAsNotABaseline() throws {
        let path = try write("usrs: []", to: "bad.json")

        XCTAssertEqual(
            message(of: configuration(baseline: path)),
            #"--baseline: '\#(path.string)' is not a Periphery baseline (expected {"v1": {"usrs": [...]}})"#
        )
    }

    func testBaseline_valid_isReturnedForFiltering() throws {
        let path = try write(#"{"v1":{"usrs":["s:3Lib6TaggedC","s:3Lib5OtherC"]}}"#, to: "baseline.json")

        let baseline = try ScanPreflight.validatePaths(of: configuration(baseline: path))

        XCTAssertEqual(baseline?.usrs, ["s:3Lib6TaggedC", "s:3Lib5OtherC"])
    }

    func testBaseline_validWithNoUsrs_isAccepted() throws {
        let path = try write(#"{"v1":{"usrs":[]}}"#, to: "baseline.json")

        XCTAssertEqual(try ScanPreflight.validatePaths(of: configuration(baseline: path))?.usrs, [])
    }

    func testBaseline_notConfigured_returnsNil() throws {
        XCTAssertNil(try ScanPreflight.validatePaths(of: configuration()))
    }

    // MARK: - Output destinations

    func testWriteResults_missingDirectory_namesTheDirectory() {
        let path = directory.appending("nodir").appending("out.txt")

        XCTAssertEqual(
            message(of: configuration(writeResults: path)),
            "--write-results: directory '\(directory.appending("nodir").string)' does not exist"
        )
    }

    func testWriteBaseline_missingDirectory_namesTheDirectory() {
        let path = directory.appending("nodir").appending("bl.json")

        XCTAssertEqual(
            message(of: configuration(writeBaseline: path)),
            "--write-baseline: directory '\(directory.appending("nodir").string)' does not exist"
        )
    }

    func testWriteResults_directoryIsAFile_isRejected() throws {
        let file = try write("", to: "afile")
        let path = file.appending("out.txt")

        XCTAssertEqual(
            message(of: configuration(writeResults: path)),
            "--write-results: directory '\(file.string)' is not a directory"
        )
    }

    func testWriteResults_destinationIsADirectory_isRejected() {
        XCTAssertEqual(
            message(of: configuration(writeResults: directory)),
            "--write-results: '\(directory.string)' is a directory"
        )
    }

    func testWriteBaseline_unwritableDirectory_isRejected() throws {
        try XCTSkipIf(geteuid() == 0, "Directory permissions do not apply to root")

        let readonly = directory.appending("readonly")
        try FileManager.default.createDirectory(atPath: readonly.string, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readonly.string)

        XCTAssertEqual(
            message(of: configuration(writeBaseline: readonly.appending("bl.json"))),
            "--write-baseline: directory '\(readonly.string)' is not writable"
        )
    }

    func testOutputDestinations_inAnExistingDirectory_pass() throws {
        let configuration = configuration(
            writeBaseline: directory.appending("bl.json"),
            writeResults: directory.appending("out.txt")
        )

        XCTAssertNil(try ScanPreflight.validatePaths(of: configuration))
    }

    func testOutputDestinations_withoutADirectoryComponent_resolveAgainstTheCurrentDirectory() throws {
        FileManager.default.changeCurrentDirectoryPath(directory.string)
        let configuration = configuration(writeBaseline: FilePath("bl.json"), writeResults: FilePath("out.txt"))

        XCTAssertNil(try ScanPreflight.validatePaths(of: configuration))
    }

    func testBaselineRewrittenInPlace_passes() throws {
        let path = try write(#"{"v1":{"usrs":["s:3Lib6TaggedC"]}}"#, to: "baseline.json")
        let configuration = configuration(baseline: path, writeBaseline: path)

        XCTAssertEqual(try ScanPreflight.validatePaths(of: configuration)?.usrs, ["s:3Lib6TaggedC"])
    }

    func testFirstFailure_isReportedInTheOrderBaselineThenWriteBaselineThenWriteResults() {
        let missing = directory.appending("nodir").appending("x")

        XCTAssertEqual(
            message(of: configuration(baseline: directory.appending("missing.json"), writeBaseline: missing, writeResults: missing)),
            "--baseline: '\(directory.appending("missing.json").string)' cannot be read (no such file)"
        )
        XCTAssertEqual(
            message(of: configuration(writeBaseline: missing, writeResults: missing)),
            "--write-baseline: directory '\(directory.appending("nodir").string)' does not exist"
        )
    }

    // MARK: - Baseline file

    func testWriteBaseline_replacesTheFileAtomically() throws {
        let path = try write("previous", to: "baseline.json")
        let inodeBefore = try inode(of: path)

        try ScanCommand.writeBaseline(.v1(usrs: ["s:3Lib6TaggedC"]), to: path)

        XCTAssertNotEqual(try inode(of: path), inodeBefore, "A non-atomic write truncates the file in place")
        let written = try JSONDecoder().decode(Baseline.self, from: Data(contentsOf: path.url))
        XCTAssertEqual(written.usrs, ["s:3Lib6TaggedC"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.string), ["baseline.json"])
    }

    private func inode(of path: FilePath) throws -> UInt {
        try XCTUnwrap(FileManager.default.attributesOfItem(atPath: path.string)[.systemFileNumber] as? UInt)
    }

    // MARK: - Ordering within the command

    func testScan_withAMissingBaseline_failsBeforeAnythingElse() throws {
        let command = try ScanCommand.parse(["--project-root", directory.string, "--baseline", "missing.json", "--quiet"])

        XCTAssertThrowsError(try command.run()) { error in
            XCTAssertEqual(
                (error as? PeripheryError)?.errorDescription,
                "--baseline: 'missing.json' cannot be read (no such file)"
            )
        }
    }

    func testScan_withAMissingResultsDirectory_failsBeforeAnythingElse() throws {
        let command = try ScanCommand.parse(["--project-root", directory.string, "--write-results", "nodir/out.txt", "--quiet"])

        XCTAssertThrowsError(try command.run()) { error in
            XCTAssertEqual(
                (error as? PeripheryError)?.errorDescription,
                "--write-results: directory 'nodir' does not exist"
            )
        }
    }
}
