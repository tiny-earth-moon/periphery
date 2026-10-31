import Configuration
import SystemPackage
@testable import TestShared

final class CrossModuleRetentionTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)
        index(configuration: Configuration())
    }

    func testCrossModuleInheritanceWithSameName() {
        module("CrossModuleRetentionFixtures") {
            self.assertReferenced(.class("FixtureClass129"))
        }

        module("CrossModuleRetentionSupportFixtures") {
            self.assertReferenced(.class("FixtureClass129"))
        }
    }

    func testCrossModuleProtocolRequirementImplementedInExtension() {
        module("CrossModuleRetentionFixtures") {
            self.assertReferenced(.struct("FixtureStruct1120")) {
                self.assertReferenced(.functionMethodInstance("calledRequirement()"))
            }
        }
    }
}
