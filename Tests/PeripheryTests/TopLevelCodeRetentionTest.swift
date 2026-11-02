import Configuration
import SystemPackage
@testable import TestShared

final class TopLevelCodeRetentionTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        let configuration = Configuration()
        configuration.superfluousIgnoreComments = true

        build(projectPath: ExecutableFixturesProjectPath)
        index(configuration: configuration)
    }

    func testTopLevelCallRetainsTypeDeclaredBeforeIt() {
        module("TopLevelCodeBox") {
            self.assertReferenced(.struct("Box")) {
                self.assertReferenced(.varInstance("value"))
            }
            self.assertNotReferenced(.functionFree("unusedFunction()"))
        }
    }

    func testTopLevelCallRetainsTypeFromAnotherModule() {
        module("TopLevelCodeLib") {
            self.assertReferenced(.struct("Gadget"))
            self.assertNotReferenced(.struct("UnreferencedGadget"))
        }

        module("TopLevelCodeCross") {
            self.assertNotReferenced(.functionFree("unusedCrossFunction()"))
        }
    }

    func testTopLevelCallsRetainTheirCalleesWhateverPrecedesThem() {
        module("TopLevelCodeScript") {
            self.assertReferenced(.functionFree("calledHelper()"))
            self.assertNotReferenced(.functionFree("unusedBeforeCall()"))
            self.assertReferenced(.struct("Runner")) {
                self.assertReferenced(.functionMethodInstance("go()"))
            }
            self.assertNotReferenced(.functionFree("unusedBeforeMethodCall()"))
        }
    }

    func testIgnoreCommentNextToTopLevelCodeIsNotSuperfluous() {
        module("TopLevelCodeScript") {
            self.assertNotSuperfluousIgnoreCommand(.varInstance("second"))
        }
    }
}
