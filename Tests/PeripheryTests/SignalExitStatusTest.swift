import Foundation
@testable import Shared
@testable import TestShared
import XCTest

/// Launches the `periphery` executable on a project whose build never finishes, signals it, and checks how it exits.
final class SignalExitStatusTest: XCTestCase {
    private var root: URL!
    private var processes: [Process] = []

    private var marker: URL {
        root.appendingPathComponent("build-started")
    }

    private var logFile: URL {
        root.appendingPathComponent("periphery.log")
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("periphery-signal-\(UUID().uuidString)")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        try """
        // swift-tools-version:5.9
        import PackageDescription
        let package = Package(name: "Fixture", targets: [.target(name: "Fixture")])
        """.write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        // Stands in for `swift`: only the build hangs, everything else (such as `swift -version`) is the real tool.
        let shim = bin.appendingPathComponent("swift")
        try """
        #!/bin/bash
        if [ "$1" = "build" ] && [ "${2:-}" != "--show-bin-path" ]; then
            echo "$$" > "$FIXTURE_MARKER.partial"
            mv "$FIXTURE_MARKER.partial" "$FIXTURE_MARKER"
            exec /bin/sleep 120
        fi
        exec "$FIXTURE_REAL_SWIFT" "$@"
        """.write(to: shim, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shim.path)

        FileManager.default.createFile(atPath: logFile.path, contents: nil)
    }

    override func tearDown() {
        for process in processes where process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }

        if let pid = buildPid {
            kill(pid, SIGKILL)
        }

        try? FileManager.default.removeItem(at: root)
    }

    func testSigintInterruptsTheBuildAndExitsWith130() throws {
        try assertExit(afterSending: SIGINT, expectedStatus: 130)
    }

    func testSigtermTerminatesTheBuildAndExitsWith143() throws {
        try assertExit(afterSending: SIGTERM, expectedStatus: 143)
    }

    // MARK: - Private

    private var buildPid: pid_t? {
        guard let text = try? String(contentsOf: marker, encoding: .utf8) else { return nil }

        return pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func assertExit(afterSending signalNumber: Int32, expectedStatus: Int32) throws {
        let (process, exited) = try launchPeriphery()
        guard waitForBuildToStart(of: process), let pid = buildPid else { return }

        kill(process.processIdentifier, signalNumber)

        guard exited.wait(timeout: .now() + 30) == .success else {
            return XCTFail("periphery did not exit within 30s of signal \(signalNumber)\n\(log())")
        }

        XCTAssertEqual(process.terminationReason, .exit, "periphery was killed by the signal instead of exiting\n\(log())")
        XCTAssertEqual(process.terminationStatus, expectedStatus, log())
        XCTAssertEqual(kill(pid, 0), -1, "the child build process is still running")
        XCTAssertEqual(errno, ESRCH)
    }

    private func launchPeriphery() throws -> (Process, DispatchSemaphore) {
        let realSwift = try ShellImpl.executableURL(for: "swift", environment: ProcessInfo.processInfo.environment)
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(root.appendingPathComponent("bin").path):\(environment["PATH"] ?? "")"
        environment["FIXTURE_MARKER"] = marker.path
        environment["FIXTURE_REAL_SWIFT"] = realSwift.path

        let log = try FileHandle(forWritingTo: logFile)
        let exited = DispatchSemaphore(value: 0)
        let process = Process()
        process.executableURL = try peripheryExecutable()
        process.arguments = ["scan", "--disable-update-check"]
        process.currentDirectoryURL = root
        process.environment = environment
        process.standardOutput = log
        process.standardError = log
        process.terminationHandler = { _ in exited.signal() }
        processes.append(process)
        try process.run()
        return (process, exited)
    }

    private func waitForBuildToStart(of process: Process) -> Bool {
        let deadline = Date().addingTimeInterval(60)

        while !FileManager.default.fileExists(atPath: marker.path) {
            guard process.isRunning else {
                XCTFail("periphery exited before the build started\n\(log())")
                return false
            }
            guard Date() < deadline else {
                XCTFail("the build did not start within 60s\n\(log())")
                return false
            }

            Thread.sleep(forTimeInterval: 0.05)
        }

        return true
    }

    private func peripheryExecutable() throws -> URL {
        try locatePeripheryExecutable(near: Self.self)
    }

    private func log() -> String {
        (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
    }
}
