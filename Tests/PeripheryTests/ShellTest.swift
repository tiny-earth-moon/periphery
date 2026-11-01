//
//  ShellTest.swift
//  Periphery
//
//  Created by Alexander Goodkind on 2026-10-25.
//

import Foundation
import Logger
@testable import Shared
import XCTest

final class ShellTest: XCTestCase {
    func testCapturesLargeOutputFromBothStreams() throws {
        let shell = ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let output = try shell.exec(command(status: 0))
        XCTAssertEqual(output, "stdout:\(String(repeating: "x", count: 262_144)):end")
    }

    func testPreservesBothStreamsOnFailure() throws {
        let shell = ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let command = command(status: 7)

        XCTAssertThrowsError(try shell.exec(command)) { error in
            guard case let PeripheryError.shellCommandFailed(cmd, status, output) = error else {
                return XCTFail("Expected a shell command failure, received \(error)")
            }

            XCTAssertEqual(cmd, command)
            XCTAssertEqual(status, 7)
            let payload = String(repeating: "x", count: 262_144)
            XCTAssertEqual(output, "stdout:\(payload):end\nstderr:\(payload):end")
        }
    }

    func testPassesArgumentsLiterallyWithoutAShell() throws {
        let shell = ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-shell-\(UUID().uuidString)")
        let hostile = "$(touch \(marker.path)) `touch \(marker.path)` 'single' \"double\" a\\b; echo injected"

        let output = try shell.exec(["printf", "%s|%s", hostile, "two words"])

        XCTAssertEqual(output, "\(hostile)|two words")
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testExecStatusPassesArgumentsLiterally() throws {
        let shell = ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let status = try shell.execStatus(["test", "$(echo a)", "=", "$(echo a)"])
        XCTAssertEqual(status, 0)
        XCTAssertEqual(try shell.execStatus(["test", "$(echo a)", "=", "a"]), 1)
    }

    func testResolvesExecutableFromPath() throws {
        let url = try ShellImpl.executableURL(for: "printf", environment: ["PATH": "/nonexistent::/usr/bin:/bin"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "printf")
        XCTAssertEqual(try ShellImpl.executableURL(for: "/bin/echo", environment: [:]).path, "/bin/echo")
    }

    func testThrowsWhenExecutableIsNotInPath() {
        XCTAssertThrowsError(try ShellImpl.executableURL(for: "periphery-no-such-tool", environment: ["PATH": "/usr/bin"])) { error in
            guard case let PeripheryError.executableNotFound(name, searchPath) = error else {
                return XCTFail("Expected executableNotFound, received \(error)")
            }

            XCTAssertEqual(name, "periphery-no-such-tool")
            XCTAssertEqual(searchPath, ["/usr/bin"])
        }
    }

    func testShellQuotedRendersCommandForDisplay() {
        XCTAssertEqual(
            ["xcodebuild", "-scheme", "My $(App)", "it's", ""].shellQuoted,
            "xcodebuild -scheme 'My $(App)' 'it'\\''s' ''"
        )
    }

    private func command(status: Int) -> [String] {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/ShellOutput.sh")
        return ["/bin/bash", fixture.path, String(status)]
    }
}
