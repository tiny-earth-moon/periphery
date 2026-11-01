import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class AssetCatalogResultFormatTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private func result(assetName: String?, assetPaths: [FilePath]) -> ScanResult {
        let file = SourceFile(path: FilePath("/DerivedSources/GeneratedAssetSymbols.swift"), modules: ["App"])
        let declaration = Declaration(name: "accent", kind: .varStatic, usrs: ["s:accent"], location: Location(file: file, line: 3, column: 16))
        let symbol = AssetCatalogSymbol(kind: .color, assetName: assetName, assetPaths: assetPaths)
        return ScanResult(declaration: declaration, annotation: .unusedAssetCatalogSymbol(symbol))
    }

    func testXcodeOutput_namesTheColorAndItsColorset() throws {
        let output = try XcodeFormatter(configuration: Configuration(), logger: logger)
            .format([result(assetName: "AccentColor", assetPaths: [FilePath("/App/Assets.xcassets/AccentColor.colorset")])], colored: false)

        XCTAssertEqual(output, "/DerivedSources/GeneratedAssetSymbols.swift:3:16: warning: Unused asset catalog color 'AccentColor' (/App/Assets.xcassets/AccentColor.colorset)")
    }

    func testXcodeOutput_omitsTheColorsetWhenNoCatalogDeclaresIt() throws {
        let output = try XcodeFormatter(configuration: Configuration(), logger: logger)
            .format([result(assetName: "AccentColor", assetPaths: [])], colored: false)

        XCTAssertEqual(output, "/DerivedSources/GeneratedAssetSymbols.swift:3:16: warning: Unused asset catalog color 'AccentColor'")
    }

    func testResultKind_isTheColorAnnotation() {
        XCTAssertEqual(ResultKind.identifier(of: result(assetName: "AccentColor", assetPaths: [])), "unusedAssetCatalogColor.var.static")
        XCTAssertTrue(ResultKind.isValid("unusedAssetCatalogColor"))
    }
}
