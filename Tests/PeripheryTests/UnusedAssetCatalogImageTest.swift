#if os(macOS)
    @testable import PeripheryKit
    import SourceGraph
    import SystemPackage
    @testable import TestShared
    import XCTest

    final class UnusedAssetCatalogImageTest: FixtureSourceGraphTestCase {
        private let generatedSymbols = FixturesProjectPath.appending("Sources/UnusedAssetCatalogImageFixtures/GeneratedAssetSymbols.swift")
        private let catalog = FixturesProjectPath.appending("AssetCatalogs/FixtureAssets.xcassets")
        private let xib = FixturesProjectPath.appending("AssetCatalogs/FixtureImageView.xib")
        private let plist = FixturesProjectPath.appending("AssetCatalogs/FixtureInfo.plist")

        func testDetectsUnusedAssetCatalogImages() {
            let results = analyze(
                retainPublic: true,
                additionalFilesToIndex: [generatedSymbols],
                xibPaths: [xib],
                plistPaths: [plist],
                detectUnusedAssetCatalogImages: true
            ) {
                assertReferenced(.struct("FixtureStruct1500"))
            }
            let images = assetCatalogResults(results).sorted { ($0.1.assetName ?? "") < ($1.1.assetName ?? "") }

            // FixtureUsedImage is used by its generated symbol, FixtureResourceUsedImage by its resource, FixtureNamedImage
            // by name from Swift, FixtureXibImage and FixtureXibButtonImage from a xib, FixtureLaunchImage from an
            // Info.plist. The AppIcon app icon set has no generated symbol, and colors are not detected.
            XCTAssertEqual(images.map(\.1), [
                AssetCatalogSymbol(kind: .image, assetName: "FixtureUnusedImage", assetPaths: [catalog.appending("FixtureUnusedImage.imageset")]),
                AssetCatalogSymbol(kind: .image, assetName: "FixtureUnusedSymbol", assetPaths: [catalog.appending("FixtureUnusedSymbol.symbolset")]),
            ])
            XCTAssertEqual(images.map(\.0.name), ["fixtureUnusedImage", "fixtureUnusedSymbol"])
            XCTAssertEqual(images.map { $0.0.parent?.name }, ["ImageResource", "ImageResource"])
            XCTAssertFalse(images.contains { $0.1.assetName == "AppIcon" })
            XCTAssertEqual(
                results.filter { $0.declaration.location.file.path == generatedSymbols }.count,
                2,
                "only the unused images are reported from the generated file, once each"
            )
        }

        func testDetectsNothingWithoutTheOption() {
            let results = analyze(retainPublic: true, additionalFilesToIndex: [generatedSymbols], detectUnusedAssetCatalogColors: true) {
                assertReferenced(.struct("FixtureStruct1501"))
            }
            let symbols = assetCatalogResults(results).map(\.1)

            XCTAssertFalse(symbols.contains { $0.kind == .image })
            XCTAssertEqual(symbols.map(\.assetName), ["FixtureImageTestColor"])

            let defaultResults = analyze(retainPublic: true, additionalFilesToIndex: [generatedSymbols]) {
                assertReferenced(.struct("FixtureStruct1501"))
            }

            XCTAssertTrue(assetCatalogResults(defaultResults).isEmpty)
        }

        // MARK: - Private

        private func assetCatalogResults(_ results: [ScanResult]) -> [(Declaration, AssetCatalogSymbol)] {
            results.compactMap { result in
                guard case let .unusedAssetCatalogSymbol(symbol) = result.annotation else { return nil }

                return (result.declaration, symbol)
            }
        }
    }
#endif
