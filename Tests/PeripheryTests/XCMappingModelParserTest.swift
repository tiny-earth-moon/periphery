import Foundation
@testable import Indexer
import SystemPackage
import XCTest

final class XCMappingModelParserTest: XCTestCase {
    func testThrowsForMissingFile() {
        XCTAssertThrowsError(try XCMappingModelParser(input: .directory(missingPath("xcmappingmodel"))).parse())
    }
}

private func missingPath(_ fileExtension: String) -> FilePath {
    FilePath(FileManager.default.temporaryDirectory.appendingPathComponent("Missing-\(UUID().uuidString).\(fileExtension)").path)
}
