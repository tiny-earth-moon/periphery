import Foundation
@testable import Indexer
import SystemPackage
import XCTest

final class InfoPlistParserTest: XCTestCase {
    func testThrowsForMissingFile() {
        XCTAssertThrowsError(try InfoPlistParser(path: missingPath("plist")).parse())
    }
}

private func missingPath(_ fileExtension: String) -> FilePath {
    FilePath(FileManager.default.temporaryDirectory.appendingPathComponent("Missing-\(UUID().uuidString).\(fileExtension)").path)
}
