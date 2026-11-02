import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

final class EntryPointRetentionTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: ExecutableFixturesProjectPath)
        index(configuration: Configuration())
    }

    func testMainAttributeOnExtensionRetainsTheExtendedType() {
        module("EntryPointExtension") {
            self.assertReferenced(.enum("Tool")) {
                self.assertReferenced(.functionMethodStatic("main()"))
                self.assertReferenced(.functionMethodStatic("helper()"))
                self.assertNotReferenced(.functionMethodStatic("unusedHelper()"))
            }
        }
    }

    func testMainAttributeOnExtensionDoesNotReportTheExtension() {
        let reported = Self.results.filter {
            $0.declaration.location.file.modules.contains("EntryPointExtension")
        }

        XCTAssertEqual(reported.map(\.declaration.name), ["unusedHelper()"])
    }
}
