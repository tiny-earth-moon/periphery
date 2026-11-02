import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

/// Baselines record the ids of empty extensions, which must not change when the lines above them do.
final class EmptyExtensionIdTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    private func plainResult() throws -> ScanResult {
        let configuration = Configuration()
        configuration.enableEmptyExtensionAnalysis = true
        configuration.projectRoot = AccessibilityProjectPath
        index(configuration: configuration)

        return try XCTUnwrap(Self.results.first {
            guard case .emptyExtension = $0.annotation else { return false }

            return $0.declaration.name == "EmptyExtensionPlain"
        })
    }

    func testResultId_holdsTheRelativeFileButNeitherPositionNorAbsolutePath() throws {
        XCTAssertEqual(try plainResult().usrs, ["empty-extension-EmptyExtensionPlain-Sources/TargetA/EmptyExtension.swift"])
    }

    func testBaselineWithTheLegacyPositionalId_stillFiltersTheResult() throws {
        let result = try plainResult()
        let legacyId = "empty-extension-EmptyExtensionPlain-Sources/TargetA/EmptyExtension.swift:13:11"
        let configuration = Configuration()
        configuration.projectRoot = AccessibilityProjectPath

        XCTAssertEqual(result.legacyUsrs(projectRoot: AccessibilityProjectPath), [legacyId])
        XCTAssertEqual(try OutputDeclarationFilter(configuration: configuration, logger: Self.logger).filter([result], with: .v1(usrs: [legacyId])).count, 0)
    }
}
