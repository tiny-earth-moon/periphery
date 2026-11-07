import Configuration
import Foundation
@testable import PeripheryKit
import Shared
import SystemPackage
import XCTest

final class ReportExcludeConfigurationTest: XCTestCase {
    private func load(_ yaml: String) throws -> Configuration {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-report-exclude-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent(".periphery.yml")
        try yaml.write(to: file, atomically: true, encoding: .utf8)
        let configuration = Configuration()
        try configuration.load(from: FilePath(file.path)) { XCTFail("Unexpected warning \($0)") }
        return configuration
    }

    func testStringsObjectsAndCompactForm() throws {
        let configuration = try load("""
        report_exclude:
          - "**/Generated/*.swift"
          - path: "**/SharedKit/**"
            kinds: [unused.function, unused.var.parameter]
          - "**/Other/*.swift:unused.var,redundantProtocol"
        """)

        XCTAssertEqual(configuration.reportExclude, [
            .pattern("**/Generated/*.swift"),
            .scoped(path: "**/SharedKit/**", kinds: ["unused.function", "unused.var.parameter"]),
            .pattern("**/Other/*.swift:unused.var,redundantProtocol"),
        ])

        let rules = try ReportExcludeRule.resolve(configuration)
        XCTAssertEqual(rules.map(\.kinds), [nil, ["unused.function", "unused.var.parameter"], ["unused.var", "redundantProtocol"]])
    }

    func testColonInGlobIsNotSplit() throws {
        let configuration = Configuration()
        configuration.reportExclude = [.pattern("Sources/a:b.swift"), .pattern("Sources/*:*")]
        XCTAssertEqual(try ReportExcludeRule.resolve(configuration).map(\.kinds), [nil, nil])
    }

    func testUnknownKindIsAnError() throws {
        for entry in [
            ReportExcludeEntry.scoped(path: "a", kinds: ["unused.bogus"]),
            .scoped(path: "a", kinds: []),
            .pattern("a:unused.functoin"),
            .malformed("42"),
        ] {
            let configuration = Configuration()
            configuration.reportExclude = [entry]
            XCTAssertThrowsError(try ReportExcludeRule.resolve(configuration), "\(entry)")
        }
    }

    func testMalformedYamlEntryIsAnError() throws {
        let configuration = try load("""
        report_exclude:
          - path: "a"
            kind: [unused]
        """)
        XCTAssertThrowsError(try ReportExcludeRule.resolve(configuration))
    }

    func testYamlRoundTrip() throws {
        let configuration = Configuration()
        configuration.reportExclude = [.pattern("a"), .scoped(path: "b", kinds: ["unused"])]
        let yaml = try configuration.asYaml()
        XCTAssertTrue(yaml.contains("kinds"))
        XCTAssertTrue(yaml.contains("unused"))
    }
}
