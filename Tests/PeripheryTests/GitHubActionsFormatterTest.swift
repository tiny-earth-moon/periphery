import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class GitHubActionsFormatterTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private func result(name: String, path: String = "Sources/Lib/Tagged.swift") -> ScanResult {
        let file = SourceFile(path: FilePath(path), modules: ["Lib"])
        let declaration = Declaration(name: name, kind: .class, usrs: ["s:3Lib6TaggedC"], location: Location(file: file, line: 2, column: 20))
        return ScanResult(declaration: declaration, annotation: .unused)
    }

    private func format(_ results: [ScanResult]) throws -> String {
        let configuration = Configuration()
        configuration.relativeResults = true
        return try XCTUnwrap(GitHubActionsFormatter(configuration: configuration, logger: logger).format(results, colored: false))
    }

    func testOutput_leavesPlainResultsUntouched() throws {
        XCTAssertEqual(
            try format([result(name: "Tagged")]),
            "::warning file=Sources/Lib/Tagged.swift,line=2,col=20,title=unused::Unused class 'Tagged'"
        )
    }

    func testOutput_escapesPropertyDelimitersInTheFilePath() throws {
        let output = try format([result(name: "Tagged", path: "Sources/a,b:c.swift")])

        XCTAssertTrue(output.hasPrefix("::warning file=Sources/a%2Cb%3Ac.swift,line=2,col=20,"), output)
    }

    func testOutput_escapesPercentAndNewlinesInTheMessage() throws {
        let output = try format([result(name: "50%\r\nof,it: done")])

        XCTAssertTrue(output.hasSuffix("::Unused class '50%25%0D%0Aof,it: done'"), output)
        XCTAssertFalse(output.contains("\n"))
    }
}
