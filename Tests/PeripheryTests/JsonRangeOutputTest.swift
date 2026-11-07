import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

/// The json format emits the range of each declaration as `range`, additively: every other format stays the same.
final class JsonRangeOutputTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)
    private let file = SourceFile(path: FilePath("/Project/Sources/Lib/Widget.swift"), modules: ["Lib"])

    private func results(withRanges: Bool) -> [ScanResult] {
        let widget = Declaration(name: "Widget", kind: .class, usrs: ["s:3Lib6WidgetC"], location: Location(file: file, line: 4, column: 7))
        let size = Declaration(name: "size", kind: .varInstance, usrs: ["s:3Lib6WidgetC4sizeSivp"], location: Location(file: file, line: 5, column: 9))
        size.parent = widget
        let moved = Declaration(name: "moved", kind: .functionFree, usrs: ["s:3Lib5movedyyF"], location: Location(file: file, line: 9, column: 6))
        moved.commentCommands = [.override([.location(FilePath("/Project/Sources/Lib/Other.swift"), 1, 1)])]
        let implicit = Declaration(name: "init", kind: .functionConstructor, usrs: ["s:3Lib6WidgetCACycfc"], location: Location(file: file, line: 4, column: 7))

        if withRanges {
            widget.range = DeclarationRange(
                start: SourcePosition(line: 4, column: 1),
                end: SourcePosition(line: 6, column: 2),
                attributesStart: SourcePosition(line: 3, column: 1),
                docCommentStart: SourcePosition(line: 2, column: 1)
            )
            size.range = DeclarationRange(start: SourcePosition(line: 5, column: 5), end: SourcePosition(line: 5, column: 21))
            moved.range = DeclarationRange(start: SourcePosition(line: 9, column: 1), end: SourcePosition(line: 9, column: 15))
        }

        return [widget, size, moved, implicit].map { ScanResult(declaration: $0, annotation: .unused) }
    }

    func testJson_emitsTheRangeWithItsAttributesAndDocCommentStarts() throws {
        let output = try XCTUnwrap(JsonFormatter(configuration: Configuration(), logger: logger).format(results(withRanges: true), colored: false))
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]])
        let ranges = objects.map { $0["range"] as? NSDictionary }

        XCTAssertEqual(ranges[0], [
            "start": ["line": 4, "column": 1],
            "end": ["line": 6, "column": 2],
            "attributesStart": ["line": 3, "column": 1],
            "docCommentStart": ["line": 2, "column": 1],
        ] as NSDictionary)
        XCTAssertEqual(ranges[1], [
            "start": ["line": 5, "column": 5],
            "end": ["line": 5, "column": 21],
        ] as NSDictionary)
        // The range of a declaration whose location is overridden lies in another file, and an implicit
        // declaration has none.
        XCTAssertEqual(objects.count, 4)
        XCTAssertNil(objects[2]["range"])
        XCTAssertNil(objects[3]["range"])
    }

    func testEveryOtherFormat_isUnchangedByTheRanges() throws {
        for format in OutputFormat.allCases where format != .json {
            let formatter = format.formatter.init(configuration: Configuration(), logger: logger)
            let withRanges = try formatter.format(results(withRanges: true), colored: false)
            let withoutRanges = try formatter.format(results(withRanges: false), colored: false)
            XCTAssertEqual(withRanges, withoutRanges, "\(format)")
        }
    }
}
