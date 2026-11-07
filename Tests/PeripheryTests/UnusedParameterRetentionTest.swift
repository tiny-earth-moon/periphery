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

    func testPropertyWrappedParameters() {
        analyze(retainPublic: true) {
            assertReferenced(.class("WrappedParameterHost")) {
                self.assertReferenced(.functionMethodInstance("viaProjection(level:)")) {
                    self.assertUsedParameter("level")
                }
                self.assertReferenced(.functionMethodInstance("viaStorage(level:)")) {
                    self.assertUsedParameter("level")
                }
                self.assertReferenced(.functionMethodInstance("viaValue(level:)")) {
                    self.assertUsedParameter("level")
                }
                self.assertReferenced(.functionMethodInstance("unusedWrapped(level:)")) {
                    self.assertNotReferenced(.varParameter("level"))
                }
            }
        }
    }

    func testWrapperInitializerRetention() {
        analyze(retainPublic: true) {
            assertReferenced(.struct("Bounded")) {
                self.assertReferenced(.functionConstructor("init(wrappedValue:_:)"))
                self.assertNotReferenced(.functionConstructor("init(other:)"))
            }
        }
    }

    func testUnavailableStubs() {
        analyze(retainPublic: true) {
            assertReferenced(.class("UnavailableStubHost")) {
                for name in ["plain(value:)", "withMessage(value:)", "renamedStub(value:)", "extraWhitespace(value:)", "commasInMessage(value:)"] {
                    self.assertReferenced(.functionMethodInstance(name)) {
                        self.assertUsedParameter("value")
                    }
                }
                self.assertReferenced(.functionMethodInstance("deprecatedOnly(value:)")) {
                    self.assertNotReferenced(.varParameter("value"))
                }
            }
        }
    }

    func testBareWrapperInitializersCalledImplicitly() {
        analyze(retainPublic: true) {
            assertReferenced(.struct("FixtureTrimmed")) {
                self.assertReferenced(.functionConstructor("init(wrappedValue:)"))
                self.assertReferenced(.functionConstructor("init(projectedValue:)"))
                self.assertNotReferenced(.functionConstructor("init(unused:)"))
            }
            assertReferenced(.class("FixtureTrimmedHost")) {
                for name in ["viaProjection(name:)", "viaStorage(name:)", "forwardsProjection(name:)"] {
                    self.assertReferenced(.functionMethodInstance(name)) {
                        self.assertUsedParameter("name")
                    }
                }
            }
        }
    }
}
