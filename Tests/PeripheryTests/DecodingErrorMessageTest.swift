import Configuration
import Foundation
import Logger
@testable import PeripheryKit
@testable import ProjectDrivers
import Shared
import SystemPackage
import XCTest

private struct Item: Decodable {
    let name: String
}

private struct Document: Decodable {
    // outskirts:ignore - only decoded: the tests check the message of the decoding error, never the value
    let items: [Item]
}

final class DecodingErrorMessageTest: XCTestCase {
    private final class FailingShell: Shell, @unchecked Sendable {
        func exec(_: [String]) throws -> String {
            XCTFail("The shell must not be used")
            return ""
        }
    }

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-decoding-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testReadableReasonNamesTheKeyAtFault() throws {
        let missing = try reason(Document.self, #"{"items": [{"name": "a"}, {}]}"#)
        let wrongType = try reason(Document.self, #"{"items": [{"name": 1}]}"#)

        XCTAssertEqual(missing, "missing key 'items[1].name'")
        XCTAssertEqual(wrongType, "'items[0].name' must be a string")
    }

    func testInvalidBaselineFailsWithAReadableMessage() throws {
        for json in ["{}", #"{"v1": {"usrs": "a"}}"#, "not json"] {
            let file = try write(json)

            XCTAssertThrowsError(try Baseline.load(from: file), json) { error in
                let message = error.localizedDescription
                XCTAssertTrue(message.hasPrefix("Invalid baseline \(file.string): "), message)
                XCTAssertFalse(message.contains("DecodingError"), message)
            }
        }
    }

    func testValidBaselineLoads() throws {
        let file = try write(#"{"v1": {"usrs": ["s:1a", "s:1b"]}}"#)

        XCTAssertEqual(try Baseline.load(from: file).usrs, ["s:1a", "s:1b"])
    }

    func testInvalidPackageManifestFailsWithAReadableMessage() throws {
        let file = try write(#"{"targets": [{"name": "A", "type": "regular"}]}"#)
        let configuration = Configuration()
        configuration.jsonPackageManifestPath = file
        let package = SPM.Package(configuration: configuration, shell: FailingShell(), logger: Logger(quiet: true, verbose: false, colorMode: .never))

        XCTAssertThrowsError(try package.load()) { error in
            XCTAssertEqual(error.localizedDescription, "Invalid package manifest \(file.string): missing key 'targets[0].path'")
        }
    }

    // MARK: - Private

    private func write(_ json: String) throws -> FilePath {
        let file = directory.appendingPathComponent("file-\(UUID().uuidString).json")
        try json.write(to: file, atomically: true, encoding: .utf8)
        return FilePath(file.path)
    }

    private func reason<T: Decodable>(_: T.Type, _ json: String) throws -> String {
        do {
            _ = try JSONDecoder().decode(T.self, from: Data(json.utf8))
        } catch let error as DecodingError {
            return error.readableReason()
        }

        XCTFail("The document unexpectedly decoded")
        return ""
    }
}
