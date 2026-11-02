import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

final class UnusedParameterRetentionTest: FixtureSourceGraphTestCase {
    func testIsolatedParameters() {
        analyze(retainPublic: true) {
            assertReferenced(.class("IsolatedParameterHost")) {
                self.assertReferenced(.functionMethodInstance("inheritsIsolation(isolation:)")) {
                    self.assertUsedParameter("isolation")
                }
                self.assertReferenced(.functionMethodInstance("runsOnActor(_:)")) {
                    self.assertUsedParameter("actor")
                }
                self.assertReferenced(.functionMethodInstance("labeledActor(on:)")) {
                    self.assertUsedParameter("actor")
                }
                self.assertReferenced(.functionMethodInstance("defaultIsolationValue(isolation:)")) {
                    self.assertUsedParameter("isolation")
                }
                self.assertReferenced(.functionMethodInstance("plainUnused(value:)")) {
                    self.assertNotReferenced(.varParameter("value"))
                }
                self.assertReferenced(.functionMethodInstance("nonIsolatedActor(_:)")) {
                    self.assertNotReferenced(.varParameter("actor"))
                }
            }
        }
    }
}
