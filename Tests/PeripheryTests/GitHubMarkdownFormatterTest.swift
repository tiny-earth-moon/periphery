import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class GitHubMarkdownFormatterTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private func result(name: String) -> ScanResult {
        let file = SourceFile(path: FilePath("Sources/Lib/Tagged.swift"), modules: ["Lib"])
        let declaration = Declaration(name: name, kind: .class, usrs: ["s:3Lib6TaggedC"], location: Location(file: file, line: 2, column: 20))
        return ScanResult(declaration: declaration, annotation: .unused)
    }

    private func format(_ results: [ScanResult]) throws -> String {
        try XCTUnwrap(GitHubMarkdownFormatter(configuration: Configuration(), logger: logger).format(results, colored: false))
    }

    func testOutput_rendersAPlainResultAsOneRow() throws {
        XCTAssertEqual(
            try format([result(name: "Tagged")]),
            """
            | 1 Result |
            | :- |
            | **Unused class 'Tagged'**<br>Sources/Lib/Tagged.swift:2:20 |
            """
        )
    }

    func testOutput_escapesPipesInTheCell() throws {
        let output = try format([result(name: "a|b")])

        XCTAssertTrue(output.contains("| **Unused class 'a\\|b'**<br>"), output)
    }

    func testOutput_keepsEachResultOnASingleLine() throws {
        let output = try format([result(name: "multi\nline\r\nname")])
        let rows = output.components(separatedBy: "\n")

        XCTAssertEqual(rows.count, 3, output)
        XCTAssertTrue(rows[2].contains("'multi line name'"), output)
    }
}
