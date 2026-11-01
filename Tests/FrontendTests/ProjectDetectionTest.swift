import Configuration
import Foundation
@testable import Frontend
import Logger
import Shared
import SystemPackage
import XCTest

final class ProjectDetectionTest: XCTestCase {
    private var directory: URL!
    private var originalDirectory: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalDirectory = FileManager.default.currentDirectoryPath
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-project-detection-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(directory.path))
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(originalDirectory)
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testBazelWorkspaceWithAPackageManifestIsDetectedAsSwiftPM() throws {
        try write("MODULE.bazel")
        try write("WORKSPACE")
        try write("Package.swift")

        guard case .spm = try makeProject().kind else {
            return XCTFail("Expected a SwiftPM project")
        }
    }

    func testBazelWorkspaceWithAnXcodeProjectIsDetectedAsXcode() throws {
        try write("MODULE.bazel")
        try write("WORKSPACE")
        let configuration = Configuration()
        configuration.project = FilePath("App.xcodeproj")

        guard case let .xcode(projectPath) = try makeProject(configuration).kind else {
            return XCTFail("Expected an Xcode project")
        }

        XCTAssertEqual(projectPath, FilePath("App.xcodeproj"))
    }

    func testBazelWorkspaceAloneIsNotAProject() throws {
        try write("MODULE.bazel")
        try write("WORKSPACE")

        XCTAssertThrowsError(try makeProject()) { error in
            guard case PeripheryError.usageError = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    // MARK: - Private

    private func write(_ name: String) throws {
        try Data().write(to: directory.appendingPathComponent(name))
    }

    private func makeProject(_ configuration: Configuration = Configuration()) throws -> Project {
        try Project(
            configuration: configuration,
            shell: UnexpectedShell(),
            logger: Logger(quiet: true, verbose: false, colorMode: .never)
        )
    }
}

private struct UnexpectedShell: Shell {
    func exec(_ args: [String]) throws -> String {
        throw PeripheryError.shellCommandFailed(cmd: args, status: 1, output: "unexpected command")
    }

    func execStatus(_ args: [String]) throws -> Int32 {
        throw PeripheryError.shellCommandFailed(cmd: args, status: 1, output: "unexpected command")
    }
}
