#if os(macOS)
    @testable import TestShared
    import XCTest

    final class SwiftUIWidgetRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsTextFieldStyleBody() {
            analyze(retainPublic: true) {
                assertReferenced(.struct("TextFieldStyleFixture")) {
                    self.assertReferenced(.functionMethodInstance("_body(configuration:)"))
                    self.assertNotReferenced(.functionMethodInstance("unusedHelper()"))
                }
                assertReferenced(.struct("ExtensionTextFieldStyleFixture")) {
                    self.assertReferenced(.functionMethodInstance("_body(configuration:)"))
                }
                assertNotReferenced(.struct("UnusedTextFieldStyleFixture"))
                assertNotReferenced(.struct("NonStyleFixture"))
            }
        }

        func testRetainsShapeStyleApply() {
            analyze(retainPublic: true) {
                assertReferenced(.struct("ShapeStyleFixture")) {
                    self.assertReferenced(.functionMethodInstance("_apply(to:)"))
                    self.assertNotReferenced(.functionMethodInstance("unusedHelper()"))
                }
                assertNotReferenced(.struct("UnusedShapeStyleFixture"))
            }
        }
    }
#endif
