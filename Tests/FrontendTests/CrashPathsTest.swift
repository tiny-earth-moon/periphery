import Configuration
import Foundation
@testable import Frontend
import Logger
import Shared
import XCTest

final class CrashPathsTest: XCTestCase {
    private var directory: URL!
    private var originalDirectory: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDirectory = FileManager.default.currentDirectoryPath
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-crash-paths-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(directory.path))
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(originalDirectory)
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testSwiftVersion_missingExecutableThrowsExecutableNotFound() {
        let shell = StubShell(result: .failure(.executableNotFound(name: "swift", searchPath: ["/bin"])))

        XCTAssertThrowsError(try SwiftVersion(shell: shell)) { error in
            guard case PeripheryError.executableNotFound(name: "swift", searchPath: _) = error else {
                return XCTFail("Unexpected error \(error)")
            }

            XCTAssertTrue(error.localizedDescription.contains("'swift' not found"))
        }
    }

    func testSwiftVersion_emptyOutputThrowsParseError() {
        assertParseError(for: "")
    }

    func testSwiftVersion_unrecognisedOutputThrowsParseError() {
        assertParseError(for: "not a compiler banner")
    }

    func testSwiftVersion_versionMarkerWithoutNumberThrowsParseError() {
        assertParseError(for: "Swift version unknown (swiftlang)")
    }

    func testSwiftVersion_parsesReleaseAndDevelopmentBanners() throws {
        let release = try SwiftVersion(shell: StubShell(result: .success("Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)\nTarget: arm64-apple-macosx15.0\n")))
        XCTAssertEqual(release.version, "6.1.2")

        let development = try SwiftVersion(shell: StubShell(result: .success("Swift version 6.2-dev (LLVM abc, Swift def)")))
        XCTAssertEqual(development.version, "6.2")
    }

    func testGuidedSetup_inEmptyDirectoryThrowsUsageError() {
        let guidedSetup = GuidedSetup(
            configuration: Configuration(),
            shell: StubShell(result: .failure(.shellCommandFailed(cmd: [], status: 1, output: "unexpected command"))),
            logger: Logger(quiet: true, verbose: false, colorMode: .never)
        )

        XCTAssertThrowsError(try guidedSetup.perform()) { error in
            guard case let PeripheryError.usageError(message) = error else {
                return XCTFail("Unexpected error \(error)")
            }

            XCTAssertTrue(message.contains(FileManager.default.currentDirectoryPath))
            XCTAssertTrue(message.contains("--generic-project-config"))
        }
    }

    // MARK: - Private

    private func assertParseError(for output: String, file: StaticString = #filePath, line: UInt = #line) {
        let shell = StubShell(result: .success(output))

        XCTAssertThrowsError(try SwiftVersion(shell: shell), file: file, line: line) { error in
            guard case PeripheryError.swiftVersionParseError = error else {
                return XCTFail("Unexpected error \(error)", file: file, line: line)
            }
        }
    }
}

private struct StubShell: Shell {
    let result: Result<String, PeripheryError>

    func exec(_: [String]) throws -> String {
        try result.get()
    }

    func execStatus(_: [String]) throws -> Int32 {
        try result.get()
        return 0
    }
}
