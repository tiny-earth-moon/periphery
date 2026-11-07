import Foundation
@testable import Shared
import XCTest

final class SwiftVersionTest: XCTestCase {
    func testSwift61IsAcceptedWithADeprecationWarningNamingTheEndOfSupport() throws {
        let swiftVersion = try SwiftVersion(fullVersion: "swift-driver version: 1.120.5 Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)\nTarget: arm64-apple-macosx15.0")

        XCTAssertNoThrow(try swiftVersion.validateVersion())
        let warning = try XCTUnwrap(swiftVersion.deprecationWarning)
        XCTAssertTrue(warning.contains("Swift 6.1.2 is deprecated"), warning)
        XCTAssertTrue(warning.contains("outskirts 4.0"), warning)
        XCTAssertFalse(warning.contains("\n"), warning)
    }

    func testSwift62AndLaterHaveNoDeprecationWarning() throws {
        for version in ["6.2", "6.2.4", "6.4.2"] {
            let swiftVersion = try SwiftVersion(fullVersion: "Apple Swift version \(version) (swiftlang-\(version))")

            XCTAssertNoThrow(try swiftVersion.validateVersion())
            XCTAssertNil(swiftVersion.deprecationWarning, version)
        }
    }

    func testVersionsBelowTheMinimumAreStillRejected() throws {
        let swiftVersion = try SwiftVersion(fullVersion: "Apple Swift version 6.1.1 (swiftlang-6.1.1)")

        XCTAssertThrowsError(try swiftVersion.validateVersion())
    }
}
