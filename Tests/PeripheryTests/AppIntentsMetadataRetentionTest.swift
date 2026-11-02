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

        func testRetainsConformanceThroughLocalRefiningProtocol() {
            analyze {
                assertReferenced(.struct("RefinedIntent"))
                assertReferenced(.protocol("BaseIntent"))
                assertReferenced(.extensionProtocol("BaseIntent"))
                assertReferenced(.struct("DeeplyRefinedIntent"))
                assertReferenced(.protocol("DeepBaseIntent"))
                assertNotReferenced(.struct("PlainConforming"))
                assertNotReferenced(.protocol("PlainBase"))
            }
        }

        func testRetainsLibraryContentProviderThroughLocalRefiningProtocol() {
            analyze {
                assertReferenced(.struct("RefinedLibraryProvider"))
                assertReferenced(.protocol("BaseLibraryProvider"))
                assertNotReferenced(.struct("PlainLibraryConforming"))
                assertNotReferenced(.protocol("PlainLibraryBase"))
            }
        }
    }
#endif
