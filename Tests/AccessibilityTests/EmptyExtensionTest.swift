import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

final class EmptyExtensionTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testNothingReportedWhenDisabled() {
        index()

        XCTAssertTrue(emptyExtensionResults.isEmpty, "Unexpected results: \(emptyExtensionResults.map(\.declaration))")
    }

    func testEmptyExtension_isReported() {
        analyze()

        assertEmptyExtension("EmptyExtensionPlain")
        assertEmptyExtension("EmptyExtensionAvailability")
        assertEmptyExtension("EmptyExtensionGeneric")
    }

    func testExtensionWithOnlyComments_isReported() {
        analyze()

        assertEmptyExtension("EmptyExtensionCommentOnly")
    }

    func testExtensionWithConformance_isNotReported() {
        analyze()

        assertNotEmptyExtension("EmptyExtensionConformance")
    }

    func testExtensionWithMember_isNotReported() {
        analyze()

        assertNotEmptyExtension("EmptyExtensionMember")
    }

    func testConditionalCompilationBlocks() {
        analyze()

        assertNotEmptyExtension("EmptyExtensionConditionalMember")
        assertEmptyExtension("EmptyExtensionConditionalEmpty")
    }

    func testIgnoreCommentCommand() {
        analyze()

        assertNotEmptyExtension("EmptyExtensionIgnored")
    }

    func testResultLocationAndKind() throws {
        analyze()

        let result = try XCTUnwrap(emptyExtensionResults.first { $0.declaration.name == "EmptyExtensionPlain" })
        XCTAssertEqual(result.declaration.location.file.path.lastComponent?.string, "EmptyExtension.swift")
        XCTAssertEqual(result.declaration.location.line, 13)
        XCTAssertEqual(result.declaration.location.column, 11)
        XCTAssertEqual(ResultKind.identifier(of: result), "emptyExtension.extension")
        XCTAssertTrue(ResultKind.isValid("emptyExtension"))
        XCTAssertEqual(emptyExtensionResults.count(where: { $0.declaration.name == "EmptyExtensionPlain" }), 1)
    }

    // MARK: - Private

    private var emptyExtensionResults: [ScanResult] {
        Self.results.filter {
            if case .emptyExtension = $0.annotation {
                return true
            }
            return false
        }
    }

    private func analyze() {
        let configuration = Configuration()
        configuration.enableEmptyExtensionAnalysis = true
        index(configuration: configuration)
    }

    private func assertEmptyExtension(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        if !emptyExtensionResults.contains(where: { $0.declaration.name == name }) {
            XCTFail("Expected an empty extension of '\(name)'", file: file, line: line)
        }
    }

    private func assertNotEmptyExtension(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        if emptyExtensionResults.contains(where: { $0.declaration.name == name }) {
            XCTFail("Unexpected empty extension of '\(name)'", file: file, line: line)
        }
    }
}
