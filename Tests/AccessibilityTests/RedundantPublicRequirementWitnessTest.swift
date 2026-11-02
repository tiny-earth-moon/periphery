@testable import TestShared
import XCTest

final class RedundantPublicRequirementWitnessTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testProtocolWitnessingExternalRequirementIsNotRedundant() {
        index()

        assertNotRedundantPublicAccessibility(.protocol("ExternalWitnessRepresentable"))
        assertNotRedundantPublicAccessibility(.extensionProtocol("ExternalWitnessRepresentable"))
    }

    func testProtocolWithoutExternalWitnessStaysRedundant() {
        index()

        assertRedundantPublicAccessibility(.protocol("ExternalWitnessControlProtocol"))
        assertRedundantPublicAccessibility(.extensionProtocol("ExternalWitnessControlProtocol"))
    }

    func testProtocolWithoutPublicConformerStaysRedundant() {
        index()

        assertRedundantPublicAccessibility(.protocol("ExternalWitnessUnadoptedProtocol"))
        assertRedundantPublicAccessibility(.extensionProtocol("ExternalWitnessUnadoptedProtocol"))
    }

    func testProtocolWitnessingLocalPublicRequirementIsNotRedundant() {
        index()

        assertNotRedundantPublicAccessibility(.protocol("ExternalWitnessLocalRefining"))
        assertNotRedundantPublicAccessibility(.extensionProtocol("ExternalWitnessLocalRefining"))
    }
}
