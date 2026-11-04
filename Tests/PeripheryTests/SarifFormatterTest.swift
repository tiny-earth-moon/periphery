import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import Shared
import SourceGraph
import SystemPackage
@testable import TestShared
import XCTest

/// Set `PERIPHERY_UPDATE_GOLDEN` to rewrite the golden file from the current output.
final class SarifFormatterTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)
    private let root = FilePath.current

    private var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PeripheryTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Fixtures")
    }

    private func location(_ path: String, modules: Set<String>, line: Int, column: Int) -> Location {
        Location(file: SourceFile(path: root.appending(path), modules: modules), line: line, column: column)
    }

    private func results() -> [ScanResult] {
        let widget = Declaration(name: "Widget", kind: .class, usrs: ["s:3Lib6WidgetC"], location: location("Sources/My Lib/Widget.swift", modules: ["Lib"], line: 3, column: 14))
        widget.accessibility = DeclarationAccessibility(value: .internal, isExplicit: false)

        let helper = Declaration(name: "helper()", kind: .functionFree, usrs: ["s:3Lib6helperyyF"], location: location("Sources/Lib/Helper.swift", modules: ["Lib"], line: 5, column: 13))
        helper.accessibility = DeclarationAccessibility(value: .public, isExplicit: true)

        let marker = Declaration(name: "Marker", kind: .protocol, usrs: ["s:4Demo6MarkerP"], location: location("Sources/Demo/Marker.swift", modules: ["Demo"], line: 1, column: 10))
        let references = [("B", 7), ("A", 6)].map { name, line in
            Reference(name: name, kind: .related, declarationKind: .struct, usr: "s:4Demo1\(name)V", location: location("Sources/Demo/main.swift", modules: ["Demo"], line: line, column: 8))
        }

        let unusedImport = Declaration(name: "Combine", kind: .module, usrs: ["import-Combine"], location: location("Sources/Lib/Widget.swift", modules: ["Lib"], line: 1, column: 1))

        let counter = Declaration(name: "counter", kind: .varInstance, usrs: ["s:3Lib7CounterC7counterSivp"], location: location("Sources/Lib/Counter.swift", modules: ["Lib"], line: 4, column: 9))

        let accent = Declaration(name: "accent", kind: .varStatic, usrs: ["s:accent"], location: location("DerivedSources/GeneratedAssetSymbols.swift", modules: ["App"], line: 3, column: 16))
        let symbol = AssetCatalogSymbol(kind: .color, assetName: "AccentColor", assetPaths: [root.appending("App/Assets.xcassets/AccentColor.colorset")])

        return [
            ScanResult(declaration: widget, annotation: .unused),
            ScanResult(declaration: helper, annotation: .redundantPublicAccessibility(modules: ["Zeta", "Alpha"])),
            ScanResult(declaration: marker, annotation: .redundantProtocol(references: Set(references), inherited: ["Base"])),
            ScanResult(declaration: unusedImport, annotation: .unused),
            ScanResult(declaration: counter, annotation: .assignOnlyProperty),
            ScanResult(declaration: accent, annotation: .unusedAssetCatalogSymbol(symbol)),
        ]
    }

    private func format(_ results: [ScanResult]) throws -> String {
        try XCTUnwrap(SarifFormatter(configuration: Configuration(), logger: logger).format(results, colored: false))
    }

    private func rootUri() -> String {
        URL(fileURLWithPath: root.string, isDirectory: true).absoluteString
    }

    private func log(_ output: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
    }

    func testSarifOutput_matchesTheGoldenFile() throws {
        // The checkout location and the release version are not part of what the fixture pins.
        let output = try format(results())
            .replacingOccurrences(of: rootUri(), with: "file:///ROOT/")
            .replacingOccurrences(of: "\"version\" : \"\(PeripheryVersion)\"", with: "\"version\" : \"VERSION\"")
        let url = fixturesDirectory.appendingPathComponent("Golden/sarif.json")

        if ProcessInfo.processInfo.environment["PERIPHERY_UPDATE_GOLDEN"] != nil {
            try Data((output + "\n").utf8).write(to: url)
        }

        let expected = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(output + "\n", expected, "The sarif output differs from \(url.path)")
    }

    func testSarifOutput_containsTheRequiredFields() throws {
        let sarif = try log(format(results()))

        XCTAssertEqual(sarif["version"] as? String, "2.1.0")
        XCTAssertEqual(sarif["$schema"] as? String, "https://json.schemastore.org/sarif-2.1.0.json")

        let runs = try XCTUnwrap(sarif["runs"] as? [[String: Any]])
        XCTAssertEqual(runs.count, 1)

        let run = runs[0]
        let driver = try XCTUnwrap((run["tool"] as? [String: Any])?["driver"] as? [String: Any])
        XCTAssertEqual(driver["name"] as? String, "outskirts")
        XCTAssertEqual(driver["version"] as? String, PeripheryVersion)
        XCTAssertNotNil(driver["informationUri"] as? String)

        let rules = try XCTUnwrap(driver["rules"] as? [[String: Any]])
        let ruleIds = rules.compactMap { $0["id"] as? String }
        XCTAssertEqual(Set(ruleIds).count, ruleIds.count)
        for rule in rules {
            XCTAssertNotNil((rule["shortDescription"] as? [String: Any])?["text"] as? String)
            XCTAssertNotNil(rule["helpUri"] as? String)
        }

        let baseIds = try XCTUnwrap(run["originalUriBaseIds"] as? [String: [String: Any]])
        XCTAssertEqual(baseIds["%SRCROOT%"]?["uri"] as? String, rootUri())

        let sarifResults = try XCTUnwrap(run["results"] as? [[String: Any]])
        XCTAssertEqual(sarifResults.compactMap { $0["ruleId"] as? String }, [
            "unused", "redundantPublicAccessibility", "redundantProtocol", "unused", "assignOnlyProperty", "unusedAssetCatalogColor",
        ])

        var fingerprints: Set<String> = []
        for result in sarifResults {
            let ruleId = try XCTUnwrap(result["ruleId"] as? String)
            XCTAssertTrue(ruleIds.contains(ruleId))
            XCTAssertEqual(result["level"] as? String, "warning")
            XCTAssertEqual(rules[try XCTUnwrap(result["ruleIndex"] as? Int)]["id"] as? String, ruleId)
            XCTAssertNotNil((result["message"] as? [String: Any])?["text"] as? String)

            let physical = try XCTUnwrap(((result["locations"] as? [[String: Any]])?.first)?["physicalLocation"] as? [String: Any])
            XCTAssertEqual((physical["artifactLocation"] as? [String: Any])?["uriBaseId"] as? String, "%SRCROOT%")
            XCTAssertGreaterThanOrEqual((physical["region"] as? [String: Int])?["startLine"] ?? 0, 1)

            let fingerprint = try XCTUnwrap((result["partialFingerprints"] as? [String: String])?["peripheryResult/v1"])
            XCTAssertEqual(fingerprint.count, 64)
            fingerprints.insert(fingerprint)
        }
        XCTAssertEqual(fingerprints.count, sarifResults.count)
    }

    func testSarifRules_linkToADocumentedSectionOfTheSite() throws {
        let run = try XCTUnwrap((log(format([]))["runs"] as? [[String: Any]])?.first)
        let rules = try XCTUnwrap(((run["tool"] as? [String: Any])?["driver"] as? [String: Any])?["rules"] as? [[String: Any]])
        XCTAssertFalse(rules.isEmpty)

        for rule in rules {
            let uri = try XCTUnwrap(rule["helpUri"] as? String)
            XCTAssertTrue(uri.hasPrefix(SarifFormatter.helpBaseUri), uri)
            let parts = uri.dropFirst(SarifFormatter.helpBaseUri.count).split(separator: "/#", maxSplits: 1).map(String.init)
            XCTAssertEqual(parts.count, 2, "\(uri) names no page and section")
            guard parts.count == 2 else { continue }

            let page = try Documentation.page(parts[0])
            XCTAssertTrue(Documentation.anchors(in: page).contains(parts[1]), "docs/\(parts[0]).md has no section #\(parts[1]) for \(uri)")
        }
    }

    func testSarifOutput_describesTheRedundantConformancesAsRelatedLocations() throws {
        let sarif = try log(format(results()))
        let run = try XCTUnwrap((sarif["runs"] as? [[String: Any]])?.first)
        let result = try XCTUnwrap((run["results"] as? [[String: Any]])?[2])
        let related = try XCTUnwrap(result["relatedLocations"] as? [[String: Any]])

        XCTAssertEqual(related.compactMap { $0["id"] as? Int }, [1, 2])
        XCTAssertEqual(related.compactMap { (($0["physicalLocation"] as? [String: Any])?["region"] as? [String: Int])?["startLine"] }, [6, 7])
        XCTAssertEqual(
            related.compactMap { ($0["message"] as? [String: String])?["text"] },
            Array(repeating: "Redundant protocol conformance 'Marker' (replace with 'Base')", count: 2)
        )
    }

    func testSarifOutput_validatesAgainstTheSarifSchema() throws {
        let schemaData = try Data(contentsOf: fixturesDirectory.appendingPathComponent("Schemas/sarif-2.1.0.json"))
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: schemaData) as? [String: Any])
        let validator = JSONSchemaValidator(schema: schema)

        XCTAssertEqual(validator.validate(try log(format(results()))), [])
        XCTAssertEqual(validator.validate(try log(format([]))), [])

        // The validator must reject a log that misses a required field.
        var broken = try log(format(results()))
        broken["version"] = nil
        XCTAssertFalse(validator.validate(broken).isEmpty)
    }

    func testSarifOutput_usesRootRelativePathsWhateverRelativeResultsSays() throws {
        for relativeResults in [false, true] {
            let configuration = Configuration()
            configuration.relativeResults = relativeResults
            let output = try XCTUnwrap(SarifFormatter(configuration: configuration, logger: logger).format(results(), colored: false))
                .replacingOccurrences(of: rootUri(), with: "")

            XCTAssertFalse(output.contains(root.string), "relativeResults: \(relativeResults)")
            XCTAssertTrue(output.contains("\"uri\" : \"Sources/My%20Lib/Widget.swift\""))
            XCTAssertTrue(output.contains("App/Assets.xcassets/AccentColor.colorset"))
        }
    }

    func testSarifOutput_withARelativeResultsBase_emitsThatBaseAndPathsFromIt() throws {
        let configuration = Configuration()
        configuration.relativeResults = true
        configuration.relativeResultsBase = root.removingLastComponent()
        let formatter = SarifFormatter(configuration: configuration, logger: logger)
        let output = try XCTUnwrap(formatter.format(results(), colored: false))
        let run = try XCTUnwrap((try log(output)["runs"] as? [[String: Any]])?.first)
        let baseIds = try XCTUnwrap(run["originalUriBaseIds"] as? [String: [String: Any]])
        let projectDirectory = try XCTUnwrap(root.lastComponent?.string)

        XCTAssertEqual(baseIds["%SRCROOT%"]?["uri"] as? String, URL(fileURLWithPath: root.removingLastComponent().string, isDirectory: true).absoluteString)
        XCTAssertTrue(output.contains("\"uri\" : \"\(projectDirectory)/Sources/My%20Lib/Widget.swift\""), output)
    }

    func testSarifOutput_isIdenticalAcrossFormatterInstances() throws {
        let results = results()
        let first = try format(results)

        for _ in 0 ..< 5 {
            XCTAssertEqual(try format(results), first)
        }
    }

    func testSarifOutput_fingerprintDependsOnTheRuleAndTheIds() throws {
        func fingerprint(_ result: ScanResult) throws -> String {
            let run = try XCTUnwrap((log(format([result]))["runs"] as? [[String: Any]])?.first)
            let sarifResult = try XCTUnwrap((run["results"] as? [[String: Any]])?.first)
            return try XCTUnwrap((sarifResult["partialFingerprints"] as? [String: String])?["peripheryResult/v1"])
        }

        let declaration = results()[0].declaration
        let unused = ScanResult(declaration: declaration, annotation: .unused)

        XCTAssertEqual(try fingerprint(unused), try fingerprint(unused))
        XCTAssertNotEqual(try fingerprint(unused), try fingerprint(ScanResult(declaration: declaration, annotation: .assignOnlyProperty)))
        XCTAssertNotEqual(try fingerprint(unused), try fingerprint(results()[1]))
    }
}
