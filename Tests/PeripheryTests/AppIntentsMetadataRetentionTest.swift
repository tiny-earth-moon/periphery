#if os(macOS)
    @testable import TestShared
    import XCTest

    final class AppIntentsMetadataRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsInferredIntentDescription() {
            analyze(retainPublic: true) {
                assertReferenced(.struct("InferredLetIntent")) {
                    self.assertReferenced(.varStatic("description"))
                    self.assertNotReferenced(.varStatic("unusedHelper"))
                }
                assertReferenced(.struct("InferredVarIntent")) {
                    self.assertReferenced(.varStatic("description"))
                }
                assertReferenced(.struct("OptionalDescriptionIntent")) {
                    self.assertReferenced(.varStatic("description"))
                }
                assertReferenced(.struct("DescribedWidget")) {
                    self.assertNotReferenced(.varStatic("description"))
                }
            }
        }
    }
#endif
