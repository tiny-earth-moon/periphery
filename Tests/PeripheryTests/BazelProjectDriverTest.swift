import Configuration
import Foundation
import Logger
@testable import ProjectDrivers
import Shared
import SystemPackage
import XCTest

final class BazelProjectDriverTest: XCTestCase {
    private var configuration: Configuration!
    private var driver: BazelProjectDriver!

    override func setUp() {
        super.setUp()
        configuration = Configuration()
        driver = BazelProjectDriver(
            configuration: configuration,
            shell: ShellMock(),
            logger: Logger(quiet: true, verbose: false, colorMode: .never)
        )
    }

    func testQueryPassesFilterAsALiteralArgument() {
        configuration.bazelFilter = "^//App' $(touch x) \""

        let arguments = driver.queryArguments

        XCTAssertEqual(arguments.count, 3)
        XCTAssertEqual(Array(arguments.prefix(2)), ["bazel", "query"])
        XCTAssertTrue(arguments[2].hasPrefix("filter('^//App' $(touch x) \"', filter('^//.*', kind('("), arguments[2])
    }

    func testQueryPassesCustomQueryUnchanged() {
        let query = "kind(\"swift_library\", //...) except attr(name, 'x', //...)"
        configuration.bazelQuery = query
        configuration.bazelFilter = "ignored"

        XCTAssertEqual(driver.queryArguments, ["bazel", "query", query])
    }

    func testRunPassesOutputPathAndBuildArgumentsAsLiteralArguments() {
        configuration.buildArguments = ["--config=ci", "--define=x=$(id) 'y'"]

        let arguments = driver.runArguments(outputPath: "/Users/me/Caches/periphery/bazel")

        XCTAssertEqual(arguments, [
            "bazel",
            "run",
            "--repo_env=PERIPHERY_BAZEL_OUTPUT_PATH=/Users/me/Caches/periphery/bazel",
            "--check_visibility=false",
            "--ui_event_filters=-info,-debug,-warning",
            "--config=ci",
            "--define=x=$(id) 'y'",
            "@periphery_generated//:scan",
        ])
    }

    func testOutputPathIsPerUserUnderTheCachePath() throws {
        let path = try BazelProjectDriver.outputPath()

        XCTAssertEqual(path, try Constants.cachePath().appending("bazel"))
        XCTAssertFalse(path.string.hasPrefix("/var/tmp"))
    }

    func testOutputDirectoryIsCreatedAndTightenedToOwnerOnly() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-bazel-\(UUID().uuidString)")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let path = FilePath(root.appendingPathComponent("bazel").path)

        try BazelProjectDriver.createOutputDirectory(at: path, fileManager: .default)
        XCTAssertEqual(try permissions(of: path), 0o700)

        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: path.string)
        try BazelProjectDriver.createOutputDirectory(at: path, fileManager: .default)
        XCTAssertEqual(try permissions(of: path), 0o700)
    }

    func testBuildFileEscapesStarlarkStrings() {
        let contents = BazelProjectDriver.buildFileContents(
            configPath: "/Users/a\"b\\c/bazel/periphery.yml",
            globalIndexStore: nil,
            targets: ["//app:App"]
        )

        XCTAssertTrue(contents.contains(#"config = "/Users/a\"b\\c/bazel/periphery.yml","#), contents)
        XCTAssertTrue(contents.contains("global_indexstore = None,"), contents)
        XCTAssertTrue(contents.contains(#""@@//app:App""#), contents)
    }

    private func permissions(of path: FilePath) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: path.string)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        return permissions.intValue & 0o777
    }
}

private struct ShellMock: Shell {
    func exec(_ args: [String]) throws -> String {
        throw PeripheryError.shellCommandFailed(cmd: args, status: 1, output: "unexpected command")
    }

    func execStatus(_ args: [String]) throws -> Int32 {
        throw PeripheryError.shellCommandFailed(cmd: args, status: 1, output: "unexpected command")
    }
}
