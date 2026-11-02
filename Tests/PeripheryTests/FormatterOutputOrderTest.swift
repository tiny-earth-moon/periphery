import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

/// Two scans of an unchanged index store must produce identical output, but Swift seeds hashing per process.
/// Formatting twice in one process reuses the seed, so these tests compare against the explicit sorted order.
final class FormatterOutputOrderTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private static let conformanceLines = Array(6 ... 13)

    private func redundantProtocolResult() -> ScanResult {
        let protocolFile = SourceFile(path: FilePath("Sources/Demo/main.swift"), modules: ["Demo"])
        let protocolDeclaration = Declaration(name: "Marker", kind: .protocol, usrs: ["s:4Demo6MarkerP"], location: Location(file: protocolFile, line: 1, column: 10))

        // Built out of order on purpose: a set has no order to preserve.
        let references = Self.conformanceLines.shuffled().map { line in
            let name = String(UnicodeScalar(UInt8(ascii: "A") + UInt8(line - 6)))
            return Reference(
                name: name,
                kind: .related,
                declarationKind: .struct,
                usr: "s:4Demo1\(name)V",
                location: Location(file: protocolFile, line: line, column: 8)
            )
        }

        return ScanResult(
            declaration: protocolDeclaration,
            annotation: .redundantProtocol(references: Set(references), inherited: [])
        )
    }

    private func configuration(relativeResults: Bool = false) -> Configuration {
        let configuration = Configuration()
        configuration.relativeResults = relativeResults
        return configuration
    }

    private func format(_ formatter: OutputFormat) throws -> String {
        let configuration = configuration(relativeResults: true)
        return try XCTUnwrap(formatter.formatter.init(configuration: configuration, logger: logger).format([redundantProtocolResult()], colored: false))
    }

    /// The line numbers captured by `pattern` in the lines mentioning `marker`, in output order.
    private func lines(in output: String, mentioning marker: String, matching pattern: String) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern)

        return output.components(separatedBy: "\n")
            .filter { $0.contains(marker) }
            .compactMap { line in
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      let captured = Range(match.range(at: 1), in: line)
                else { return nil }

                return Int(line[captured])
            }
    }

    private func assertConformanceOrder(_ lines: [Int], format: OutputFormat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lines, Self.conformanceLines, "\(format) lists the redundant conformances out of order", file: file, line: line)
    }

    func testXcodeOutput_listsRedundantConformancesInSourceOrder() throws {
        let output = try format(.xcode)

        try assertConformanceOrder(lines(in: output, mentioning: "Redundant protocol conformance", matching: #":(\d+):\d+: warning"#), format: .xcode)
    }

    func testCsvOutput_listsRedundantConformancesInSourceOrder() throws {
        let output = try format(.csv)

        try assertConformanceOrder(lines(in: output, mentioning: "redundantConformance", matching: #"main\.swift:(\d+):\d+,"#), format: .csv)
    }

    func testCheckstyleOutput_listsRedundantConformancesInSourceOrder() throws {
        let output = try format(.checkstyle)

        try assertConformanceOrder(lines(in: output, mentioning: "Redundant protocol conformance", matching: #"line="(\d+)""#), format: .checkstyle)
    }

    func testGitHubActionsOutput_listsRedundantConformancesInSourceOrder() throws {
        let output = try format(.githubActions)

        try assertConformanceOrder(lines(in: output, mentioning: "Redundant protocol conformance", matching: #"line=(\d+),"#), format: .githubActions)
    }

    func testGitHubMarkdownOutput_listsRedundantConformancesInSourceOrder() throws {
        let output = try format(.githubMarkdown)

        try assertConformanceOrder(lines(in: output, mentioning: "Redundant protocol conformance", matching: #"main\.swift:(\d+):\d+"#), format: .githubMarkdown)
    }

    func testJsonOutput_listsRedundantConformancesInSourceOrder() throws {
        let output = try format(.json)
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]])
        let conformances = objects.filter { ($0["hints"] as? [String])?.first == "redundantConformance" }
        let locations = conformances.compactMap { $0["location"] as? String }

        XCTAssertEqual(locations, Self.conformanceLines.map { "Sources/Demo/main.swift:\($0):8" })
    }

    func testJsonOutput_givesRedundantConformancesTheModulesKeyOfEveryOtherObject() throws {
        let output = try format(.json)
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]])

        XCTAssertEqual(objects.count, 1 + Self.conformanceLines.count)

        for object in objects {
            XCTAssertEqual(object["modules"] as? [String], ["Demo"], "Missing modules in \(object)")
        }
    }

    func testJsonOutput_ordersAttributesThatShareAName() throws {
        let file = SourceFile(path: FilePath("Sources/Lib/Widget.swift"), modules: ["Lib"])
        let declaration = Declaration(name: "Widget", kind: .class, usrs: ["s:3Lib6WidgetC"], location: Location(file: file, line: 3, column: 14))
        let platforms = ["iOS 18, *", "macOS 15, *", "tvOS 18, *", "watchOS 11, *", "visionOS 2, *", "macCatalyst 18, *"]
        declaration.attributes = Set(platforms.map { DeclarationAttribute(name: "available", arguments: $0) })

        let output = try XCTUnwrap(JsonFormatter(configuration: configuration(), logger: logger).format([ScanResult(declaration: declaration, annotation: .unused)], colored: false))
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]])

        XCTAssertEqual(objects.first?["attributes"] as? [String], platforms.sorted().map { "available(\($0))" })
    }

    func testJsonOutput_sortsTheKeysOfEveryObject() throws {
        try assertSortedKeys(in: format(.json), format: .json)
    }

    func testCodeClimateOutput_sortsTheKeysOfEveryObject() throws {
        try assertSortedKeys(in: format(.codeclimate), format: .codeclimate)
    }

    func testGitLabCodeQualityOutput_sortsTheKeysOfEveryObject() throws {
        try assertSortedKeys(in: format(.gitlabCodeQuality), format: .gitlabCodeQuality)
    }

    /// Checks the keys of each top-level object of a pretty printed array, whose keys are indented by four spaces.
    private func assertSortedKeys(in output: String, format: OutputFormat, file: StaticString = #filePath, line: UInt = #line) {
        var objects: [[String]] = []

        for outputLine in output.components(separatedBy: "\n") {
            if outputLine == "  {" {
                objects.append([])
            } else if outputLine.hasPrefix("    \""), !outputLine.hasPrefix("     "),
                      let end = outputLine.dropFirst(5).firstIndex(of: "\"")
            {
                objects[objects.count - 1].append(String(outputLine[outputLine.index(outputLine.startIndex, offsetBy: 5) ..< end]))
            }
        }

        XCTAssertFalse(objects.isEmpty, "No object found in \(format) output", file: file, line: line)

        for keys in objects {
            XCTAssertEqual(keys, keys.sorted(), "\(format) does not sort the keys of an object", file: file, line: line)
        }
    }
}
