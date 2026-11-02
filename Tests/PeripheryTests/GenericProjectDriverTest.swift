import Configuration
import Foundation
@testable import ProjectDrivers
import Shared
import SystemPackage
import XCTest

final class GenericProjectDriverTest: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-generic-config-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testMinimalConfigWithOnlyIndexstores() throws {
        let file = try write(#"{"indexstores": [".build/out"]}"#)

        XCTAssertNoThrow(try GenericProjectDriver(genericProjectConfig: file, configuration: Configuration()))

        let config = try GenericProjectDriver.GenericConfig.load(from: file)
        XCTAssertEqual(config.indexstores, [".build/out"])
        XCTAssertEqual(config.plists, [])
        XCTAssertEqual(config.xibs, [])
        XCTAssertEqual(config.xcdatamodels, [])
        XCTAssertEqual(config.xcmappingmodels, [])
        XCTAssertEqual(config.xcstrings, [])
        XCTAssertEqual(config.testTargets, [])
    }

    func testFullConfigFromTheReadme() throws {
        let file = try write("""
        {
            "indexstores": ["path/to/file.indexstore"],
            "test_targets": ["MyTests"],
            "plists": ["path/to/file.plist"],
            "xibs": ["path/to/file.xib", "path/to/file.storyboard"],
            "xcdatamodels": ["path/to/file.xcdatamodel"],
            "xcmappingmodels": ["path/to/file.xcmappingmodel"],
            "xcstrings": ["path/to/Localizable.xcstrings"]
        }
        """)

        XCTAssertNoThrow(try GenericProjectDriver(genericProjectConfig: file, configuration: Configuration()))

        let config = try GenericProjectDriver.GenericConfig.load(from: file)
        XCTAssertEqual(config.indexstores, ["path/to/file.indexstore"])
        XCTAssertEqual(config.testTargets, ["MyTests"])
        XCTAssertEqual(config.plists, ["path/to/file.plist"])
        XCTAssertEqual(config.xibs, ["path/to/file.xib", "path/to/file.storyboard"])
        XCTAssertEqual(config.xcdatamodels, ["path/to/file.xcdatamodel"])
        XCTAssertEqual(config.xcmappingmodels, ["path/to/file.xcmappingmodel"])
        XCTAssertEqual(config.xcstrings, ["path/to/Localizable.xcstrings"])
    }

    func testMalformedConfigFailsWithAReadableMessage() throws {
        let file = try write(#"{"plists": ["a.plist"]}"#)

        XCTAssertThrowsError(try GenericProjectDriver(genericProjectConfig: file, configuration: Configuration())) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid generic project config \(file.string): missing key 'indexstores'"
            )
        }
    }

    func testEmptyIndexstoresFailsWithAReadableMessage() throws {
        let file = try write(#"{"indexstores": []}"#)

        XCTAssertEqual(message(of: file), "Invalid generic project config \(file.string): 'indexstores' must list at least one index store")
    }

    func testWrongTypeNamesTheKeyAsSpeltInTheFile() throws {
        let plists = try write(#"{"indexstores": ["a"], "plists": "a.plist"}"#)
        let targets = try write(#"{"indexstores": ["a"], "test_targets": [1]}"#)

        XCTAssertEqual(message(of: plists), "Invalid generic project config \(plists.string): 'plists' must be a list")
        XCTAssertEqual(message(of: targets), "Invalid generic project config \(targets.string): 'test_targets[0]' must be a string")
    }

    func testNonObjectAndInvalidJsonFailWithAReadableMessage() throws {
        let list = try write(#"["a"]"#)
        let invalid = try write("{indexstores")

        XCTAssertEqual(message(of: list), "Invalid generic project config \(list.string): the top level must be a JSON object")
        XCTAssertTrue(message(of: invalid).hasPrefix("Invalid generic project config \(invalid.string): "))
        XCTAssertFalse(message(of: invalid).contains("DecodingError"))
    }

    func testMissingFileIsReported() {
        let file = FilePath(directory.appendingPathComponent("missing.json").path)

        XCTAssertThrowsError(try GenericProjectDriver(genericProjectConfig: file, configuration: Configuration())) { error in
            guard case PeripheryError.pathDoesNotExist = error else { return XCTFail("Unexpected error \(error)") }
        }
    }

    // MARK: - Private

    private func message(of file: FilePath) -> String {
        do {
            _ = try GenericProjectDriver.GenericConfig.load(from: file)
        } catch {
            return error.localizedDescription
        }

        XCTFail("The config unexpectedly loaded")
        return ""
    }

    private func write(_ json: String) throws -> FilePath {
        let file = directory.appendingPathComponent("config-\(UUID().uuidString).json")
        try json.write(to: file, atomically: true, encoding: .utf8)
        return FilePath(file.path)
    }
}
