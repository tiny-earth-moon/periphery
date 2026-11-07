import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

/// Compares the JSON based formats byte for byte with checked-in fixtures, so that any change to their output,
/// including the order of keys and of the rows that derive from a set, has to be made on purpose.
///
/// Set `PERIPHERY_UPDATE_GOLDEN` to rewrite the fixtures from the current output.
final class FormatterTests: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private var goldenDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PeripheryTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Fixtures/Golden")
    }

    /// The formats that only work with relative paths are fed paths below the working directory, so that their
    /// fixtures do not depend on where the checkout lives.
    private var root = ""

    private func path(_ path: String) -> FilePath {
        FilePath(root + path)
    }

    private func location(_ path: String, modules: Set<String>, line: Int, column: Int) -> Location {
        Location(file: SourceFile(path: self.path(path), modules: modules), line: line, column: column)
    }

    private func results() -> [ScanResult] {
        let widget = Declaration(name: "Widget", kind: .class, usrs: ["s:3Lib6WidgetC"], location: location("/Project/Sources/Lib/Widget.swift", modules: ["Lib"], line: 3, column: 14))
        widget.modifiers = ["public", "final"]
        widget.attributes = [
            DeclarationAttribute(name: "available", arguments: "macOS 15, *"),
            DeclarationAttribute(name: "available", arguments: "iOS 18, *"),
            DeclarationAttribute(name: "MainActor", arguments: nil),
        ]
        widget.range = DeclarationRange(
            start: SourcePosition(line: 3, column: 1),
            end: SourcePosition(line: 9, column: 2),
            attributesStart: SourcePosition(line: 2, column: 1),
            docCommentStart: SourcePosition(line: 1, column: 1)
        )

        let marker = Declaration(name: "Marker", kind: .protocol, usrs: ["s:4Demo6MarkerP"], location: location("/Project/Sources/Demo/Marker.swift", modules: ["Demo"], line: 1, column: 10))

        // Spread over two files and built out of order: a set has no order to preserve.
        let conformances: [(String, String, Int)] = [
            ("E", "main.swift", 10), ("B", "main.swift", 7), ("H", "main.swift", 13), ("A", "main.swift", 6),
            ("G", "Extras.swift", 4), ("D", "main.swift", 9), ("F", "Extras.swift", 2), ("C", "main.swift", 8),
        ]
        let references = conformances.map { name, file, line in
            Reference(
                name: name,
                kind: .related,
                declarationKind: .struct,
                usr: "s:4Demo1\(name)V",
                location: location("/Project/Sources/Demo/\(file)", modules: file == "main.swift" ? ["Demo"] : ["Demo", "Extras"], line: line, column: 8)
            )
        }

        let publicHelper = Declaration(name: "helper()", kind: .functionFree, usrs: ["s:3Lib6helperyyF"], location: location("/Project/Sources/Lib/Helper.swift", modules: ["Lib"], line: 5, column: 13))
        publicHelper.accessibility = DeclarationAccessibility(value: .public, isExplicit: true)
        publicHelper.range = DeclarationRange(start: SourcePosition(line: 5, column: 1), end: SourcePosition(line: 7, column: 2))

        let accent = Declaration(name: "accent", kind: .varStatic, usrs: ["s:accent"], location: location("/DerivedSources/GeneratedAssetSymbols.swift", modules: ["App"], line: 3, column: 16))
        let symbol = AssetCatalogSymbol(
            kind: .color,
            assetName: "AccentColor",
            assetPaths: [path("/Project/App/Assets.xcassets/AccentColor.colorset")]
        )

        return [
            ScanResult(declaration: widget, annotation: .unused),
            ScanResult(declaration: marker, annotation: .redundantProtocol(references: Set(references), inherited: ["Base"])),
            ScanResult(declaration: publicHelper, annotation: .redundantPublicAccessibility(modules: ["Zeta", "Alpha"])),
            ScanResult(declaration: accent, annotation: .unusedAssetCatalogSymbol(symbol)),
        ]
    }

    private func assertMatchesGolden(_ format: OutputFormat, named name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        root = format.requiresRelativePaths ? FilePath.current.string : ""
        let output = try XCTUnwrap(format.formatter.init(configuration: Configuration(), logger: logger).format(results(), colored: false), file: file, line: line)
        let url = goldenDirectory.appendingPathComponent(name)

        if ProcessInfo.processInfo.environment["PERIPHERY_UPDATE_GOLDEN"] != nil {
            try FileManager.default.createDirectory(at: goldenDirectory, withIntermediateDirectories: true)
            try Data((output + "\n").utf8).write(to: url)
        }

        let expected = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(output + "\n", expected, "The \(format) output differs from \(url.path)", file: file, line: line)
    }

    func testJsonOutput_matchesTheGoldenFile() throws {
        try assertMatchesGolden(.json, named: "json.json")
    }

    func testCodeClimateOutput_matchesTheGoldenFile() throws {
        try assertMatchesGolden(.codeclimate, named: "codeclimate.json")
    }

    func testGitLabCodeQualityOutput_matchesTheGoldenFile() throws {
        try assertMatchesGolden(.gitlabCodeQuality, named: "gitlab-codequality.json")
    }
}
