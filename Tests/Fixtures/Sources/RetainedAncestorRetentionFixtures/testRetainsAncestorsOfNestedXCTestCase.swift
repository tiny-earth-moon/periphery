import XCTest

enum TestNamespace {
    final class NestedTests: XCTestCase {
        func testNested() {
            XCTAssertTrue(true)
        }
    }

    enum Inner {
        final class DeeplyNestedTests: XCTestCase {
            func testDeeplyNested() {
                XCTAssertTrue(true)
            }
        }
    }

    static let unusedConstant = 1
}

enum ExtensionTestNamespace {}

extension ExtensionTestNamespace {
    final class ExtensionNestedTests: XCTestCase {
        func testNestedInExtension() {
            XCTAssertTrue(true)
        }
    }
}

enum UnusedNamespace {
    static let unusedConstant = 1
}
