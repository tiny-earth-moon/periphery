import Foundation
@testable import Indexer
import SystemPackage
@testable import TestShared
import XCTest

final class XibParserTest: XCTestCase {
    func testThrowsForMissingFile() {
        XCTAssertThrowsError(try XibParser(path: missingPath("xib")).parse())
    }

    func testThrowsForMissingFileWhenCollectingNamedColors() {
        XCTAssertThrowsError(try XibParser(path: missingPath("xib")).namedColors())
    }

    func testNamedAssets_collectsImageNames() throws {
        let parser = XibParser(path: FixturesProjectPath.appending("AssetCatalogs/FixtureImageView.xib"))

        XCTAssertEqual(try parser.namedAssets(colors: false, images: true), ["FixtureXibImage", "FixtureXibButtonImage"])
        XCTAssertEqual(try parser.namedAssets(colors: true, images: false), [])
    }

    func testNamedAssets_keepsColorsAndImagesApart() throws {
        let parser = XibParser(path: FixturesProjectPath.appending("AssetCatalogs/FixtureView.xib"))

        XCTAssertEqual(try parser.namedAssets(colors: false, images: true), [])
        XCTAssertEqual(try parser.namedColors(), ["FixtureXibColor"])
    }
}

private func missingPath(_ fileExtension: String) -> FilePath {
    FilePath(FileManager.default.temporaryDirectory.appendingPathComponent("Missing-\(UUID().uuidString).\(fileExtension)").path)
}
