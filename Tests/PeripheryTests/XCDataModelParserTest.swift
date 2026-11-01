import Foundation
@testable import Indexer
import SystemPackage
import XCTest

final class XCDataModelParserTest: XCTestCase {
    func testThrowsForMissingFile() throws {
        let model = FileManager.default.temporaryDirectory.appendingPathComponent("Model-\(UUID().uuidString).xcdatamodeld")
        try FileManager.default.createDirectory(at: model.appendingPathComponent("Model.xcdatamodel"), withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: model) }

        // A model version without its `contents` file.
        XCTAssertThrowsError(try XCDataModelParser(path: FilePath(model.path)).parse())
    }
}
