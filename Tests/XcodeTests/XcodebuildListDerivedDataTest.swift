import Foundation
import Logger
import Shared
import SystemPackage
@testable import XcodeSupport
import XCTest

final class XcodebuildListDerivedDataTest: XCTestCase {
    private final class RecordingShell: Shell, @unchecked Sendable {
        private(set) var commands: [[String]] = []

        func exec(_ args: [String]) throws -> String {
            commands.append(args)
            if args.first == "xcodebuild", args.contains("-list") {
                return #"{"project":{"schemes":["SchemeA"]}}"#
            }
            return "Xcode 0.0"
        }
    }

    private func makeProject(shell: Shell) throws -> (Xcodebuild, XcodeProject) {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let xcodebuild = Xcodebuild(shell: shell, logger: logger)
        var loadedProjectPaths: Set<FilePath> = []
        let project = try XcodeProject(path: UIKitProjectPath, loadedProjectPaths: &loadedProjectPaths, xcodebuild: xcodebuild, shell: shell, logger: logger)
        return (xcodebuild, project)
    }

    private func listCommand(in shell: RecordingShell) throws -> String {
        let command = try XCTUnwrap(shell.commands.last { $0.first == "xcodebuild" && $0.contains("-list") })
        return command.joined(separator: " ")
    }

    func testSchemesListRunsInPeripheryDerivedData() throws {
        let shell = RecordingShell()
        let (_, project) = try makeProject(shell: shell)

        _ = try project.schemes(additionalArguments: [])

        let command = try listCommand(in: shell)
        let cachePath = try Constants.cachePath().string
        XCTAssertTrue(command.contains("-IDECustomDerivedDataLocation=\(cachePath)/DerivedData-"), command)
        XCTAssertFalse(command.contains("'"), command)
        XCTAssertTrue(cachePath.hasSuffix("/Library/Caches/com.github.tiny-earth-moon.outskirts"), cachePath)
    }

    func testCleanBuildRemovesTheDerivedDataUsedByList() throws {
        let shell = RecordingShell()
        let (xcodebuild, project) = try makeProject(shell: shell)

        _ = try project.schemes(additionalArguments: [])
        let listCommand = try listCommand(in: shell)
        let derivedDataPath = try xcodebuild.derivedDataPath(for: project, schemes: [])
        XCTAssertTrue(listCommand.contains("-IDECustomDerivedDataLocation=\(derivedDataPath.string)"), "\(derivedDataPath) not used by \(listCommand)")

        try FileManager.default.createDirectory(atPath: derivedDataPath.string, withIntermediateDirectories: true)
        try xcodebuild.removeDerivedData(for: project, allSchemes: [])

        XCTAssertFalse(FileManager.default.fileExists(atPath: derivedDataPath.string))
    }
}
