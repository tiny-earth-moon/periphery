import Configuration
import SystemPackage
@testable import TestShared
import XCTest

final class DynamicCallableRetentionTest: FixtureSourceGraphTestCase {
    func testRetainsDynamicCallableMethods() {
        analyze {
            assertReferenced(.struct("Adder")) {
                self.assertReferenced(.functionMethodInstance("dynamicallyCall(withArguments:)")) {
                    self.assertUsedParameter("args")
                }
                self.assertReferenced(.functionMethodInstance("dynamicallyCall(withKeywordArguments:)"))
                self.assertNotReferenced(.functionMethodInstance("plainMethod()"))
            }
        }
    }

    func testRetainsDynamicCallableMethodsDeclaredInExtension() {
        analyze {
            assertReferenced(.struct("Multiplier")) {
                self.assertReferenced(.functionMethodInstance("dynamicallyCall(withArguments:)"))
            }
        }
    }
}

final class DynamicCallableCrossModuleRetentionTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)

        let configuration = Configuration()
        configuration.enableRedundantPublicMembers = true
        index(configuration: configuration)
    }

    func testRetainsPublicDynamicCallableMethodsCalledFromAnotherModule() {
        module("DynamicCallableSupportFixtures") {
            self.assertReferenced(.struct("DynamicCaller")) {
                self.assertReferenced(.functionMethodInstance("dynamicallyCall(withArguments:)"))
                self.assertReferenced(.functionMethodInstance("dynamicallyCall(withKeywordArguments:)"))
                self.assertNotReferenced(.functionMethodInstance("plainPublicMethod()"))
            }
        }
    }

    func testKeepsPublicDynamicCallableMethodsOutOfRedundantPublicMembers() {
        module("DynamicCallableSupportFixtures") {
            self.assertReferenced(.struct("DynamicCaller")) {
                self.assertNotRedundantPublicAccessibility(.functionMethodInstance("dynamicallyCall(withArguments:)"))
                self.assertNotRedundantPublicAccessibility(.functionMethodInstance("dynamicallyCall(withKeywordArguments:)"))
                // Control: a public member that is not required to be public is still reported.
                self.assertRedundantPublicAccessibility(.functionMethodInstance("usedOnlyInsideModule()"))
            }
        }
    }
}
