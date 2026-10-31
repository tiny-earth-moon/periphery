#if os(macOS)
    @testable import TestShared
    import XCTest

    final class AppIntentsRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsAppIntent() {
            analyze {
                assertReferenced(.struct("SimpleIntent"))
            }
        }

        func testRetainsAppIntentMembersImplementedInExtensions() {
            analyze {
                assertReferenced(.struct("ExtensionIntent")) {
                    self.assertReferenced(.varStatic("title"))
                    self.assertReferenced(.functionMethodInstance("perform()"))
                }
                assertReferenced(.struct("ExtensionEntity")) {
                    self.assertReferenced(.varStatic("typeDisplayRepresentation"))
                    self.assertReferenced(.varStatic("defaultQuery"))
                    self.assertReferenced(.varInstance("displayRepresentation"))
                }
                assertReferenced(.struct("ExtensionEntityQuery")) {
                    self.assertReferenced(.functionMethodInstance("entities(for:)"))
                    self.assertReferenced(.functionMethodInstance("suggestedEntities()"))
                }
            }
        }

        func testRetainsAppEntity() {
            analyze {
                assertReferenced(.struct("SimpleEntity"))
                assertReferenced(.struct("SimpleEntityQuery"))
            }
        }

        func testRetainsAppEnum() {
            analyze {
                assertReferenced(.enum("SimpleAppEnum"))
            }
        }

        func testRetainsAppShortcutsProvider() {
            analyze {
                assertReferenced(.struct("SimpleShortcutsProvider"))
            }
        }
    }
#endif
