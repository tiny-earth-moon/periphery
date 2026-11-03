import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class CodeClimateFormatterTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private func result(annotation: ScanResult.Annotation) -> ScanResult {
        let file = SourceFile(path: FilePath.current.appending("Sources/Lib/Tagged.swift"), modules: ["Lib"])
        let declaration = Declaration(name: "Tagged", kind: .class, usrs: ["s:3Lib6TaggedC"], location: Location(file: file, line: 2, column: 20))
        return ScanResult(declaration: declaration, annotation: annotation)
    }

    private func format(_ results: [ScanResult]) throws -> String {
        try XCTUnwrap(CodeClimateFormatter(configuration: Configuration(), logger: logger).format(results, colored: false))
    }

    func testCodeClimateOutput_containsRequiredSpecFields() throws {
        let output = try format([
            result(annotation: .unused),
            result(annotation: .assignOnlyProperty),
        ])
        let issues = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]])

        XCTAssertEqual(issues.count, 2)
        XCTAssertEqual(issues.map { $0["check_name"] as? String }, ["unused", "assignOnlyProperty"])
        for issue in issues {
            XCTAssertEqual(issue["type"] as? String, "issue")
            XCTAssertEqual(issue["categories"] as? [String], ["Bug Risk"])
            XCTAssertEqual(issue["severity"] as? String, "major")
            XCTAssertEqual(issue["fingerprint"] as? String, "s:3Lib6TaggedC")
            XCTAssertNotNil(issue["description"] as? String)
            let location = try XCTUnwrap(issue["location"] as? [String: Any])
            XCTAssertEqual(location["path"] as? String, "Sources/Lib/Tagged.swift")
            XCTAssertEqual((location["lines"] as? [String: Int])?["begin"], 2)
        }
    }

    func testCodeClimateOutput_isStableAcrossRuns() throws {
        let results = [result(annotation: .unused)]
        let first = try format(results)
        for _ in 0 ..< 5 {
            XCTAssertEqual(try format(results), first)
        }
    }
}
