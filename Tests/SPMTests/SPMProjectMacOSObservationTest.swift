#if os(macOS)
    import Configuration
    @testable import TestShared
    import XCTest

    final class SPMProjectMacOSObservationTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            build(projectPath: SPMProjectMacOSPath)
            index(configuration: Configuration())
        }

        func testObservableClassReportsLikePlainClass() {
            assertReferenced(.class("ObservedStore")) {
                self.assertReferenced(.varInstance("readValue"))
                self.assertReferenced(.varInstance("assignedFromOutside"))
                self.assertReferenced(.varInstance("boundValue"))
                self.assertNotReferenced(.varInstance("neverTouched"))
                self.assertAssignOnlyProperty(.varInstance("assignedOnly"))
                self.assertAssignOnlyProperty(.varInstance("initializedOnly"))
                self.assertNotReferenced(.varInstance("ignoredNeverTouched"))
            }
            assertReferenced(.class("PlainStore")) {
                self.assertReferenced(.varInstance("readValue"))
                self.assertNotReferenced(.varInstance("neverTouched"))
                self.assertAssignOnlyProperty(.varInstance("assignedOnly"))
                self.assertAssignOnlyProperty(.varInstance("initializedOnly"))
            }
        }

        func testObservablePropertyReadInPropertyObserver() {
            assertReferenced(.class("HydratingStore")) {
                self.assertReferenced(.varInstance("isHydrating"))
                self.assertNotAssignOnlyProperty(.varInstance("isHydrating"))
                self.assertReferenced(.varInstance("isLoading"))
                self.assertNotAssignOnlyProperty(.varInstance("isLoading"))
                self.assertAssignOnlyProperty(.varInstance("neverRead"))
            }
        }

        func testRetainsModelClassProperties() {
            assertReferenced(.class("PersistedItem")) {
                self.assertReferenced(.varInstance("title"))
                self.assertReferenced(.varInstance("neverTouched"))
            }
        }
    }
#endif
