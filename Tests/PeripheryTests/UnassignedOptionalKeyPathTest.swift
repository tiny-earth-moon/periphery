import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

final class UnassignedOptionalKeyPathTest: FixtureSourceGraphTestCase {
    func testStoredKeyPathWritesAreNotReported() {
        analyze(retainPublic: true, enableUnassignedOptionalAnalysis: true) {
            assertReferenced(.class("FixtureStoredKeyPathTarget")) {
                self.assertNotUnassignedOptionalProperty(.varInstance("direct"))
                self.assertNotUnassignedOptionalProperty(.varInstance("viaFunction"))
                self.assertNotUnassignedOptionalProperty(.varInstance("viaStored"))
                self.assertUnassignedOptionalProperty(.varInstance("neverAssigned"))
            }
        }
    }

    #if canImport(Combine)
        func testStoredKeyPathAssignIsNotReported() {
            // The key path is written inside `#if`, whose names are retained by default.
            analyze(retainPublic: true, enableUnassignedOptionalAnalysis: true, disablePlatformConditionalRetention: true) {
                assertReferenced(.class("FixtureStoredKeyPathAssignTarget")) {
                    self.assertNotUnassignedOptionalProperty(.varInstance("viaAssign"))
                    self.assertUnassignedOptionalProperty(.varInstance("neverAssigned"))
                }
            }
        }
    #endif
}
