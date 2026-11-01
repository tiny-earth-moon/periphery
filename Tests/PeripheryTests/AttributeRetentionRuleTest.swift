import Configuration
import Shared
@testable import SourceGraph
import XCTest

final class AttributeRetentionRuleTest: XCTestCase {
    private func resolve(_ entries: [String]) throws -> [AttributeRetentionRule] {
        let configuration = Configuration()
        configuration.retainAttributes = entries
        return try AttributeRetentionRule.resolve(configuration)
    }

    func testAttributeAlone() throws {
        XCTAssertEqual(
            try resolve(["OptionGroup", "@MainActor"]),
            [
                AttributeRetentionRule(attribute: "OptionGroup", kinds: nil),
                AttributeRetentionRule(attribute: "MainActor", kinds: nil),
            ]
        )
    }

    func testAttributeWithKinds() throws {
        XCTAssertEqual(
            try resolve(["objc:function.method.instance, var"]),
            [AttributeRetentionRule(attribute: "objc", kinds: ["function.method.instance", "var"])]
        )
    }

    func testDefaultIsEmpty() throws {
        XCTAssertEqual(try resolve([]), [])
    }

    func testUnknownKindOrMalformedEntryIsAnError() {
        for entry in ["objc:bogus", "objc:function,bogus", "objc:", "objc:var,", ":var", "@", ""] {
            XCTAssertThrowsError(try resolve([entry]), entry) { error in
                guard case PeripheryError.usageError = error else {
                    return XCTFail("unexpected error \(error) for \(entry)")
                }
            }
        }
    }
}
