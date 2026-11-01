import Foundation
@testable import Indexer
import SystemPackage
import XCTest

final class XibParserTest: XCTestCase {
    func testThrowsForMissingFile() {
        XCTAssertThrowsError(try XibParser(path: missingPath("xib")).parse())
    }

    func testThrowsForMissingFileWhenCollectingNamedColors() {
        XCTAssertThrowsError(try XibParser(path: missingPath("xib")).namedColors())
    }
}

private func missingPath(_ fileExtension: String) -> FilePath {
    FilePath(FileManager.default.temporaryDirectory.appendingPathComponent("Missing-\(UUID().uuidString).\(fileExtension)").path)
}
