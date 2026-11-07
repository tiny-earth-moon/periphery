import Configuration
import Foundation
@testable import PeripheryKit
@testable import TestShared
import XCTest

/// Baselines record the ids of unused imports, which must not change when the lines above them do.
final class UnusedImportIdTest: SPMSourceGraphTestCase {
    private static let relativeFile = "Sources/UnusedSystemImportFixtures/UnusedFoundationImport.swift"

    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)
    }

    private func unusedImportResult() throws -> ScanResult {
        let configuration = Configuration()
        configuration.enableUnusedSystemImports = true
        configuration.projectRoot = FixturesProjectPath
        index(
            sourceFiles: [FixturesProjectPath.appending(Self.relativeFile)],
            configuration: configuration
        )

        return try XCTUnwrap(Self.results.first { $0.declaration.kind == .module })
    }

    func testResultId_holdsTheRelativeFileButNeitherPositionNorAbsolutePath() throws {
        XCTAssertEqual(try unusedImportResult().usrs, ["import-Foundation-\(Self.relativeFile)"])
    }

    func testBaselineWithTheLegacyPositionalId_stillFiltersTheResult() throws {
        let result = try unusedImportResult()
        let legacyId = "import-Foundation-\(Self.relativeFile):1:1"
        let configuration = Configuration()
        configuration.projectRoot = FixturesProjectPath

        XCTAssertEqual(result.legacyUsrs(projectRoot: FixturesProjectPath), [legacyId])
        XCTAssertEqual(try OutputDeclarationFilter(configuration: configuration, logger: Self.logger).filter([result], with: .v1(usrs: [legacyId])).count, 0)
    }
}
