import ArgumentParser
@testable import Frontend
import XCTest

final class RemovedBazelOptionsTest: XCTestCase {
    private static let removedOptions: [[String]] = [
        ["--bazel"],
        ["--bazel-filter", "^//app"],
        ["--bazel-filter=^//app"],
        ["--bazel-query", "kind(swift_library, //...)"],
        ["--bazel-index-store", "/tmp/index"],
        ["--bazel-check-visibility"],
    ]

    func testRemovedOptionsFailWithTheRemovalMessage() {
        for arguments in Self.removedOptions {
            XCTAssertThrowsError(try ScanCommand.parse(arguments), "\(arguments)") { error in
                let message = ScanCommand.message(for: error)
                let option = arguments[0].split(separator: "=")[0]
                XCTAssertEqual(
                    message,
                    "'\(option)' is no longer supported: Bazel support was removed in 3.13.0. The agoodkind/periphery fork maintains a Bazel mode.",
                    "\(arguments)"
                )
            }
        }
    }

    func testRemovedOptionIsRejectedAmongValidOptions() {
        XCTAssertThrowsError(try ScanCommand.parse(["--strict", "--bazel", "--quiet"])) { error in
            XCTAssertTrue(ScanCommand.message(for: error).contains("Bazel support was removed in 3.13.0"))
        }
    }

    func testBazelIsAbsentFromTheHelp() {
        XCTAssertFalse(ScanCommand.helpMessage().contains("--bazel"))
    }

    func testScanWithoutRemovedOptionsStillParses() throws {
        let command = try ScanCommand.parse(["--strict", "--quiet"])
        XCTAssertEqual(command.strict, true)
        XCTAssertEqual(command.quiet, true)
    }

    func testArgumentsAfterTheSeparatorBelongToTheBuildTool() throws {
        let command = try ScanCommand.parse(["--", "--bazel"])
        XCTAssertEqual(command.buildArguments, ["--bazel"])
    }
}
