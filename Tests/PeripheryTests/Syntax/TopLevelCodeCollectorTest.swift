import SwiftParser
import SwiftSyntax
@testable import SyntaxAnalysis
import XCTest

final class TopLevelCodeCollectorTest: XCTestCase {
    private func collect(_ source: String) -> TopLevelCodeRanges {
        let syntax = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "main.swift", tree: syntax)
        return TopLevelCodeCollector.collect(from: syntax, locationConverter: converter)
    }

    func testCollectsStatementsAndExpressionsButNotDeclarations() {
        let ranges = collect("""
        struct Item {}
        func helper() {}
        helper()
        let value = Item()
        if value.isEmpty {
            print(value)
        }
        """)

        XCTAssertFalse(ranges.contains(line: 1, column: 8))
        XCTAssertFalse(ranges.contains(line: 2, column: 6))
        XCTAssertTrue(ranges.contains(line: 3, column: 1))
        XCTAssertTrue(ranges.contains(line: 3, column: 8))
        XCTAssertFalse(ranges.contains(line: 4, column: 13), "A global initializer is a declaration")
        XCTAssertTrue(ranges.contains(line: 5, column: 4))
        XCTAssertTrue(ranges.contains(line: 6, column: 11))
        XCTAssertTrue(ranges.contains(line: 7, column: 1))
    }

    func testCollectsStatementsInsideConditionalCompilationBlocks() {
        let ranges = collect("""
        #if DEBUG
        func debugOnly() {}
        debugOnly()
        #else
        print("release")
        #endif
        """)

        XCTAssertFalse(ranges.contains(line: 2, column: 6))
        XCTAssertTrue(ranges.contains(line: 3, column: 3))
        XCTAssertTrue(ranges.contains(line: 5, column: 3))
    }

    func testFileWithoutTopLevelCodeIsEmpty() {
        let ranges = collect("""
        struct Item {}
        #Preview { Item() }
        """)

        XCTAssertTrue(ranges.isEmpty)
        XCTAssertFalse(ranges.contains(line: 2, column: 12))
    }
}
