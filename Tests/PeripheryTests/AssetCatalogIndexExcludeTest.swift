import Configuration
import Extensions
@testable import Indexer
import SystemPackage
import XCTest

final class AssetCatalogIndexExcludeTest: XCTestCase {
    // Index exclude globs are relative to the current directory.
    private let derivedSources = FilePath.current.appending("DerivedData/Build/Intermediates.noindex/App.build/Debug/App.build/DerivedSources")
    private lazy var generated = derivedSources.appending("GeneratedAssetSymbols.swift")
    private lazy var otherGenerated = derivedSources.appending("resource_bundle_accessor.swift")
    private let source = FilePath.current.appending("Sources/App/View.swift")

    private func configuration(detectColors: Bool) -> Configuration {
        let configuration = Configuration()
        configuration.detectUnusedAssetCatalogColors = detectColors
        configuration.buildFilenameMatchers()
        return configuration
    }

    func testGeneratedAssetSymbols_isExcludedByDefault() {
        let configuration = configuration(detectColors: false)

        XCTAssertTrue(configuration.isIndexExcluded(generated))
        XCTAssertFalse(configuration.isAnalyzedGeneratedAssetSymbolsFile(generated))
        XCTAssertEqual(Indexer(configuration: configuration).filterIndexExcluded(from: [generated, source]).included, [source])
    }

    func testGeneratedAssetSymbols_isIndexedWhenDetectingColors() {
        let configuration = configuration(detectColors: true)

        XCTAssertFalse(configuration.isIndexExcluded(generated))
        XCTAssertTrue(configuration.isAnalyzedGeneratedAssetSymbolsFile(generated))
        XCTAssertEqual(Indexer(configuration: configuration).filterIndexExcluded(from: [generated, source]).included, [generated, source])
    }

    func testOtherBuildFiles_stayExcludedWhenDetectingColors() {
        let configuration = configuration(detectColors: true)

        XCTAssertTrue(configuration.isIndexExcluded(otherGenerated))
        XCTAssertEqual(configuration.indexExclude, configuration.$indexExclude.defaultValue)
    }
}
