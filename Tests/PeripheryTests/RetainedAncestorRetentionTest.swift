#if os(macOS)
    @testable import TestShared
    import XCTest

    final class RetainedAncestorRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsAncestorsOfNestedXCTestCase() {
            analyze {
                assertReferenced(.enum("TestNamespace")) {
                    self.assertReferenced(.class("NestedTests")) {
                        self.assertReferenced(.functionMethodInstance("testNested()"))
                    }
                    self.assertReferenced(.enum("Inner")) {
                        self.assertReferenced(.class("DeeplyNestedTests"))
                    }
                    self.assertNotReferenced(.varStatic("unusedConstant"))
                }
                assertReferenced(.enum("ExtensionTestNamespace")) {
                    self.assertReferenced(.class("ExtensionNestedTests"))
                }
                assertNotReferenced(.enum("UnusedNamespace"))
            }
        }

        func testRetainsAncestorsOfNestedAppIntent() {
            analyze {
                assertReferenced(.enum("IntentNamespace")) {
                    self.assertReferenced(.struct("NestedIntent"))
                    self.assertNotReferenced(.varStatic("unusedConstant"))
                }
                assertNotReferenced(.enum("UnusedIntentNamespace"))
            }
        }

        func testRetainsAncestorsOfNestedLibraryContentProvider() {
            analyze {
                assertReferenced(.enum("ProviderNamespace")) {
                    self.assertReferenced(.struct("NestedLibraryProvider"))
                }
                assertNotReferenced(.enum("UnusedProviderNamespace"))
            }
        }

        func testRetainsAncestorsOfNestedSwiftTestingSuite() {
            analyze {
                assertReferenced(.enum("SuiteNamespace")) {
                    self.assertReferenced(.struct("NestedSuite")) {
                        self.assertReferenced(.functionMethodInstance("nestedTest()"))
                    }
                    self.assertReferenced(.enum("Inner")) {
                        self.assertReferenced(.struct("PlainContainer")) {
                            self.assertReferenced(.functionMethodInstance("containedTest()"))
                        }
                    }
                }
                assertNotReferenced(.enum("UnusedSuiteNamespace"))
            }
        }
    }
#endif
