import Configuration
import SystemPackage
@testable import TestShared
import XCTest

/// Imports of modules used only inside a platform conditional `#if` block of a platform that was not built.
final class UnusedImportPlatformConditionalTest: SPMSourceGraphTestCase {
    private static let fixtureDirectory = FixturesProjectPath.appending("Sources/UnusedImportPlatformFixtures")

    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)
    }

    func testImportUsedOnlyInPlatformConditionalIsNotReported() {
        indexFixtures()

        XCTAssertEqual(unusedImportedModules(inFileNamed: "PlatformOnlyUse.swift"), [])
    }

    func testImportNamedOnlyInPlatformConditionalIsNotReported() {
        indexFixtures()

        XCTAssertEqual(unusedImportedModules(inFileNamed: "PlatformOnlyModuleQualifiedUse.swift"), [])
    }

    func testImportIsReportedWhenPlatformConditionalUsesNothingFromTheModule() {
        indexFixtures()

        XCTAssertEqual(
            unusedImportedModules(inFileNamed: "PlatformBlockWithoutModuleUse.swift"),
            ["UnusedImportPlatformSupportFixtures"]
        )
    }

    func testImportIsReportedWhenPlatformConditionalRetentionIsDisabled() {
        let configuration = Configuration()
        configuration.disablePlatformConditionalRetention = true
        indexFixtures(configuration: configuration)

        XCTAssertEqual(
            unusedImportedModules(inFileNamed: "PlatformOnlyUse.swift"),
            ["UnusedImportPlatformSupportFixtures"]
        )
    }

    func testSystemImportIsKeptWhenPlatformConditionalNamesAnUnresolvedDeclaration() {
        let configuration = Configuration()
        configuration.enableUnusedSystemImports = true
        indexFixtures(configuration: configuration)

        XCTAssertEqual(unusedImportedModules(inFileNamed: "PlatformSystemUse.swift"), [])
    }

    // System module detection relies on the Darwin SDK layout; not reported on Linux yet (#280).
    #if os(macOS)
        func testSystemImportIsReportedWhenPlatformConditionalNamesOnlyScannedDeclarations() {
            let configuration = Configuration()
            configuration.enableUnusedSystemImports = true
            indexFixtures(configuration: configuration)

            XCTAssertEqual(unusedImportedModules(inFileNamed: "PlatformBlockWithoutSystemUse.swift"), ["Foundation"])
        }
    #endif

    // MARK: - Private

    private func indexFixtures(configuration: Configuration = Configuration()) {
        let files = [
            "Support/PlatformSupport.swift",
            "Client/PlatformOnlyUse.swift",
            "Client/PlatformOnlyModuleQualifiedUse.swift",
            "Client/PlatformBlockWithoutModuleUse.swift",
            "System/PlatformSystemUse.swift",
            "System/PlatformBlockWithoutSystemUse.swift",
        ]
        index(sourceFiles: files.map { Self.fixtureDirectory.appending($0) }, configuration: configuration)
    }
}
