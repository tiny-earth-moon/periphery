import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
@testable import TestShared
import XCTest

final class ScanSummaryTest: FixtureSourceGraphTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    func testFileWhoseTopLevelDeclarationsAreAllUnusedIsListed_andFileWithAUsedDeclarationIsNot() throws {
        let summary = try summarizeScan(of: ["testScanSummaryUnusedFile", "testScanSummaryPartlyUsedFile"])

        XCTAssertEqual(summary.unusedFiles, [ScanSummary.UnusedFile(path: fixturePath("testScanSummaryUnusedFile"), lineCount: 22)])
    }

    func testRemovableLinesOfAScanEqualTheHandCountedLines() throws {
        let summary = try summarizeScan(of: ["testScanSummaryUnusedFile", "testScanSummaryPartlyUsedFile"])

        // SummaryUnusedClass, doc comment and attribute included: lines 3-12; SummaryUnusedStruct: 16-18; its
        // extension: 20-22; SummaryLeftoverClass: 5 of the other file.
        XCTAssertEqual(summary.removableLineCount, 10 + 3 + 3 + 1)
        XCTAssertEqual(summary.countsByAnnotation["unused"], 4)
    }

    func testNestedReportedDeclarationsAreCountedOnce() {
        let results = [
            result("SummaryUnusedClass", .class, line: 6, column: 13),
            result("Nested", .struct, line: 7, column: 12),
            result("nestedMethod()", .functionMethodInstance, line: 8, column: 14),
            result("method()", .functionMethodInstance, line: 11, column: 10),
        ]

        let summary = summarize(results)

        XCTAssertEqual(summary.removableLineCount, 10)
        XCTAssertEqual(summary.resultCount, 4)
        XCTAssertEqual(summary.unusedFiles, [], "SummaryUnusedStruct is not reported")
    }

    func testResultsThatDoNotRemoveCodeAreCountedButAddNoLines() {
        let results = [
            result("SummaryUnusedClass", .class, line: 6, column: 13, annotation: .redundantPublicAccessibility(modules: ["Fixtures"])),
            result("SummaryUnusedStruct", .struct, line: 16, column: 8, annotation: .missingFinal),
            result("value", .varInstance, line: 17, column: 9, annotation: .assignOnlyProperty),
            result("SummaryUnusedStruct", .extensionStruct, line: 20, column: 11, annotation: .emptyExtension),
        ]

        let summary = summarize(results)

        XCTAssertEqual(summary.removableLineCount, 3, "only the extension removes code")
        XCTAssertEqual(summary.countsByAnnotation, ["redundantPublicAccessibility": 1, "missingFinal": 1, "assignOnlyProperty": 1, "emptyExtension": 1])
        XCTAssertEqual(summary.unusedFiles, [])
    }

    func testFormatsOtherThanJsonAreByteIdenticalWithTheSummary() throws {
        let results = sampleResults()
        let summary = summarize(results)

        for format in OutputFormat.allCases where format != .json {
            let formatter = format.formatter.init(configuration: Configuration(), logger: logger)
            XCTAssertEqual(
                try formatter.format(results, summary: summary, colored: false),
                try formatter.format(results, colored: false),
                "\(format)"
            )
        }
    }

    func testJsonWithTheSummaryHoldsTheResultsAndASummaryObject() throws {
        let results = sampleResults()
        let formatter = OutputFormat.json.formatter.init(configuration: Configuration(), logger: logger)

        let plain = try XCTUnwrap(formatter.format(results, colored: false))
        let withSummary = try XCTUnwrap(formatter.format(results, summary: summarize(results), colored: false))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(withSummary.utf8)) as? [String: Any])
        XCTAssertEqual(object.keys.sorted(), ["results", "summary"])
        let plainResults = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(plain.utf8)) as? NSArray)
        XCTAssertEqual(object["results"] as? NSArray, plainResults)
        XCTAssertEqual(object["summary"] as? NSDictionary, [
            "total": 4,
            "counts": ["unused": 3, "missingFinal": 1],
            "removableLines": 16,
            "unusedFiles": [["path": fixturePath("testScanSummaryUnusedFile").string, "lines": 22]],
        ] as NSDictionary)
    }

    func testTextSummaryListsCountsLinesAndUnusedFiles() {
        let results = sampleResults()
        let formatter = OutputFormat.xcode.formatter.init(configuration: Configuration(), logger: logger)

        XCTAssertEqual(formatter.describe(summarize(results), colored: false), """
        * Summary: 4 results (unused: 3, missingFinal: 1)
        * Removable lines (estimate): 16
        * Files entirely unused: 1
          \(fixturePath("testScanSummaryUnusedFile").string) (22 lines)
        """)
    }

    // MARK: - Private

    private func summarizeScan(of fixtures: [String]) throws -> ScanSummary {
        let configuration = Configuration()
        configuration.retainPublic = true
        configuration.buildFilenameMatchers()
        Self.index(sourceFiles: fixtures.map(fixturePath), configuration: configuration)

        return summarize(Self.results)
    }

    /// The three top-level declarations of the unused fixture, and a result that removes nothing.
    private func sampleResults() -> [ScanResult] {
        [
            result("SummaryUnusedClass", .class, line: 6, column: 13),
            result("SummaryUnusedStruct", .struct, line: 16, column: 8),
            result("SummaryUnusedStruct", .extensionStruct, line: 20, column: 11),
            result("SummaryKeptClass", .class, line: 1, column: 14, file: "testScanSummaryPartlyUsedFile", annotation: .missingFinal),
        ]
    }

    private func summarize(_ results: [ScanResult]) -> ScanSummary {
        OutputFormat.xcode.formatter.init(configuration: Configuration(), logger: logger).summarize(results)
    }

    private func result(
        _ name: String,
        _ kind: Declaration.Kind,
        line: Int,
        column: Int,
        file: String = "testScanSummaryUnusedFile",
        annotation: ScanResult.Annotation = .unused
    ) -> ScanResult {
        let location = Location(file: SourceFile(path: fixturePath(file), modules: ["RetentionFixtures"]), line: line, column: column)
        return ScanResult(declaration: Declaration(name: name, kind: kind, usrs: ["s:\(name)\(line)"], location: location), annotation: annotation)
    }

    private func fixturePath(_ fixture: String) -> FilePath {
        FixturesProjectPath.appending("Sources/RetentionFixtures/\(fixture).swift")
    }
}
