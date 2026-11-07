import Foundation
@testable import TestShared
import XCTest

/// Runs `outskirts fix` on a small package in a git repository: the dry run, the dirty-file refusal, `--apply`,
/// the rescan of the fixed package, which must build and report nothing more to fix, `--verify` and `--aggressive`.
final class FixCommandEndToEndTest: XCTestCase {
    private static let options = [
        "--disable-update-check", "--enable-empty-extension-analysis", "--superfluous-ignore-comments",
        "--enable-redundant-access-level-analysis",
    ]

    private static let library = """
    // Fixture header.

    import Helpers

    public struct Widget {
        public init() {}

        public func render(width: Int, _ height: Int) -> Int {
            helper() + internalValue() + libraryOnly()
        }

        // periphery:ignore
        func helper() -> Int { 1 }

        internal func internalValue() -> Int { 2 }
    }

    public func libraryOnly() -> Int { 3 }

    /// Doc of the empty extension.
    extension Widget {}

    """

    private static let fixedLibrary = """
    // Fixture header.

    public struct Widget {
        public init() {}

        public func render(width _: Int, _: Int) -> Int {
            helper() + internalValue() + libraryOnly()
        }

        func helper() -> Int { 1 }

        func internalValue() -> Int { 2 }
    }

    func libraryOnly() -> Int { 3 }

    """

    private var package: URL!

    override func setUpWithError() throws {
        package = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-fix-e2e-\(UUID().uuidString)")
        addTeardownBlock { [package] in
            if let package {
                try? FileManager.default.removeItem(at: package)
            }
        }

        try write("""
        // swift-tools-version:5.9
        import PackageDescription
        let package = Package(name: "Fixture", targets: [
            .target(name: "Helpers"),
            .target(name: "Lib", dependencies: ["Helpers"]),
            .executableTarget(name: "App", dependencies: ["Lib"]),
        ])
        """, to: "Package.swift")
        try write("public func helperValue() -> Int { 1 }\n", to: "Sources/Helpers/Helpers.swift")
        try write(Self.library, to: "Sources/Lib/Lib.swift")
        try write("import Lib\n\nprint(Widget().render(width: 1, 2))\n", to: "Sources/App/main.swift")
        try write(".build/\n", to: ".gitignore")
        try git("init", "-q")
        try commitAll()
    }

    func testFixesThePackageAndTheRescanIsClean() throws {
        try write(Self.library + "// uncommitted\n", to: "Sources/Lib/Lib.swift")
        let dirty = try run(["fix"])
        XCTAssertEqual(dirty.status, 0, dirty.stderr)
        XCTAssertEqual(dirty.stdout, "")
        XCTAssertTrue(dirty.stderr.contains("uncommitted changes, use --allow-dirty"), dirty.stderr)
        try write(Self.library, to: "Sources/Lib/Lib.swift")

        let dryRun = try run(["fix"])
        XCTAssertEqual(dryRun.status, 0, dryRun.stderr)
        XCTAssertTrue(dryRun.stdout.hasPrefix("--- a/Sources/Lib/Lib.swift\n+++ b/Sources/Lib/Lib.swift\n"), dryRun.stdout)
        XCTAssertTrue(dryRun.stderr.contains("Would apply 7 fixes in 1 file, skipped 0."), dryRun.stderr)
        XCTAssertEqual(try read("Sources/Lib/Lib.swift"), Self.library)

        let applied = try run(["fix", "--apply"])
        XCTAssertEqual(applied.status, 0, applied.stderr)
        XCTAssertEqual(applied.stdout, "")
        XCTAssertEqual(try read("Sources/Lib/Lib.swift"), Self.fixedLibrary)

        try commitAll()
        let rescan = try run(["fix"])
        XCTAssertEqual(rescan.status, 0, "the fixed package builds:\n\(rescan.stderr)")
        XCTAssertEqual(rescan.stdout, "")
        XCTAssertTrue(rescan.stderr.contains("Would apply 0 fixes in 0 files, skipped 0."), rescan.stderr)
    }

    func testFileEditedAfterItsIndexWasWrittenIsRefused() throws {
        let built = try run(["fix"])
        XCTAssertEqual(built.status, 0, built.stderr)

        try write(Self.library + "// edited after the build\n", to: "Sources/Lib/Lib.swift")
        try commitAll()
        let stale = try run(["fix", "--skip-build"])

        XCTAssertEqual(stale.status, 0, stale.stderr)
        XCTAssertEqual(stale.stdout, "")
        XCTAssertTrue(stale.stderr.contains("file changed since indexing"), stale.stderr)
    }

    func testRuleFilterOnlyAppliesTheGivenRule() throws {
        let output = try run(["fix", "--rule", "unused-parameter"])

        XCTAssertEqual(output.status, 0, output.stderr)
        XCTAssertTrue(output.stdout.contains("+    public func render(width _: Int, _: Int) -> Int {"), output.stdout)
        XCTAssertFalse(output.stdout.contains("-import Helpers"), output.stdout)
        XCTAssertTrue(output.stderr.contains("Would apply 2 fixes in 1 file, skipped 0.\n  unused-parameter: 2"), output.stderr)
    }

    // MARK: - Verify

    func testVerifyKeepsTheFixesWhenTheProjectBuilds() throws {
        let output = try run(["fix", "--apply", "--verify"])

        XCTAssertEqual(output.status, 0, output.stderr)
        XCTAssertTrue(output.stderr.contains("The project builds with the fixes."), output.stderr)
        XCTAssertEqual(try read("Sources/Lib/Lib.swift"), Self.fixedLibrary)
    }

    func testVerifyRestoresEveryFileWhenTheFixesBreakTheBuild() throws {
        // The client of `libraryOnly()` is excluded from the index, so its `public` is reported as redundant.
        try write("import Lib\n\nfunc excludedClient() -> Int { libraryOnly() }\n", to: "Sources/App/Excluded.swift")
        try commitAll()
        let originalBytes = try Data(contentsOf: package.appendingPathComponent("Sources/Lib/Lib.swift"))

        let output = try run(["fix", "--apply", "--verify", "--index-exclude", "Sources/App/Excluded.swift"])

        XCTAssertNotEqual(output.status, 0, output.stderr)
        XCTAssertTrue(output.stderr.contains("The build failed after the fixes were applied"), output.stderr)
        XCTAssertTrue(output.stderr.contains("The fixes break the build, restored 1 of 1 file:\n  restored Sources/Lib/Lib.swift"), output.stderr)
        XCTAssertEqual(try Data(contentsOf: package.appendingPathComponent("Sources/Lib/Lib.swift")), originalBytes)
    }

    func testVerifyRefusesASkippedBuild() throws {
        let built = try run(["fix"])
        XCTAssertEqual(built.status, 0, built.stderr)

        for arguments in [["--skip-build"], ["--index-store-path", ".build/debug/index/store"]] {
            let output = try run(["fix", "--apply", "--verify"] + arguments)

            XCTAssertNotEqual(output.status, 0, output.stderr)
            XCTAssertTrue(output.stderr.contains("'--verify' rebuilds the project after writing the fixes, but the build is skipped"), output.stderr)
            XCTAssertEqual(try read("Sources/Lib/Lib.swift"), Self.library)
        }

        let withoutApply = try run(["fix", "--verify"])
        XCTAssertNotEqual(withoutApply.status, 0)
        XCTAssertTrue(withoutApply.stderr.contains("it requires '--apply'"), withoutApply.stderr)
    }

    // MARK: - Aggressive

    func testAggressiveAddsFinalOnlyWithTheFlagAndTheOpenFinalAnalysis() throws {
        try write("final class Done {}\n\nclass Box {\n    let value = 1\n}\n", to: "Sources/App/Box.swift")
        try write("import Lib\n\nprint(Widget().render(width: 1, 2) + Box().value, Done())\n", to: "Sources/App/main.swift")
        try commitAll()

        let aggressive = try run(["fix", "--aggressive", "--rule", "missing-final", "--enable-open-final-analysis"])
        XCTAssertEqual(aggressive.status, 0, aggressive.stderr)
        XCTAssertTrue(aggressive.stdout.contains("-class Box {\n+final class Box {"), aggressive.stdout)
        XCTAssertFalse(aggressive.stdout.contains("+final final class Done"), aggressive.stdout)
        XCTAssertTrue(aggressive.stderr.contains("Would apply 1 fix in 1 file, skipped 0.\n  missing-final: 1"), aggressive.stderr)

        let tierOne = try run(["fix", "--enable-open-final-analysis"])
        XCTAssertEqual(tierOne.status, 0, tierOne.stderr)
        XCTAssertFalse(tierOne.stdout.contains("final class Box"), tierOne.stdout)

        let analysisDisabled = try run(["fix", "--aggressive"])
        XCTAssertEqual(analysisDisabled.status, 0, analysisDisabled.stderr)
        XCTAssertFalse(analysisDisabled.stdout.contains("final class Box"), analysisDisabled.stdout)

        let ruleWithoutFlag = try run(["fix", "--rule", "missing-final"])
        XCTAssertNotEqual(ruleWithoutFlag.status, 0)
        XCTAssertTrue(ruleWithoutFlag.stderr.contains("'missing-final' is a tier-2 rule, it requires '--aggressive'"), ruleWithoutFlag.stderr)
    }

    // MARK: - Private

    private struct Output {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private func write(_ text: String, to path: String) throws {
        let url = package.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: package.appendingPathComponent(path), encoding: .utf8)
    }

    private func commitAll() throws {
        try git("add", "-A")
        try git("-c", "user.name=fixture", "-c", "user.email=fixture@example.com", "commit", "-q", "-m", "fixture")
    }

    private func git(_ arguments: String...) throws {
        let output = try execute(URL(fileURLWithPath: "/usr/bin/env"), ["git"] + arguments)
        XCTAssertEqual(output.status, 0, "git \(arguments.joined(separator: " ")): \(output.stderr)")
    }

    private func run(_ arguments: [String]) throws -> Output {
        try execute(locatePeripheryExecutable(near: Self.self), arguments + Self.options)
    }

    private func execute(_ executable: URL, _ arguments: [String]) throws -> Output {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-fix-e2e-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stdoutFile = directory.appendingPathComponent("stdout")
        let stderrFile = directory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: stdoutFile.path, contents: nil)
        FileManager.default.createFile(atPath: stderrFile.path, contents: nil)

        let exited = DispatchSemaphore(value: 0)
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = package
        process.standardOutput = try FileHandle(forWritingTo: stdoutFile)
        process.standardError = try FileHandle(forWritingTo: stderrFile)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()

        if exited.wait(timeout: .now() + 300) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            XCTFail("\(executable.lastPathComponent) did not exit within 300s")
        }

        return try Output(
            status: process.terminationStatus,
            stdout: String(contentsOf: stdoutFile, encoding: .utf8),
            stderr: String(contentsOf: stderrFile, encoding: .utf8)
        )
    }
}
