import Configuration
@testable import TestShared
import XCTest

final class RedundantPublicMembersTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testMembersNotUsedCrossModule() {
        analyze()

        assertNotRedundantPublicAccessibility(.struct("RpmPublicStruct")) {
            self.assertRedundantPublicAccessibility(.functionMethodInstance("rpmNotUsedCrossModule()"))
            self.assertRedundantPublicAccessibility(.varInstance("rpmPropertyNotUsedCrossModule"))
            self.assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmUsedCrossModule()"))
            self.assertNotRedundantPublicAccessibility(.functionConstructor("init()"))
        }
    }

    func testMemberUsedByTestableImportOnly() {
        analyze()

        assertRedundantPublicAccessibility(.functionMethodInstance("rpmUsedByTestsOnly()"))
    }

    func testProtocolWitnesses() {
        analyze()

        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmRequirement()"))
        assertNotRedundantPublicAccessibility(.varInstance("rpmRequirementProperty"))
        assertNotRedundantPublicAccessibility(.varInstance("description"))
        assertNotRedundantPublicAccessibility(.functionOperatorInfix("==(_:_:)"))
        assertNotRedundantPublicAccessibility(.functionConstructor("init(from:)"))
    }

    func testInlinableMember() {
        analyze()

        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmInlinable()"))
    }

    func testNestedType() {
        analyze()

        assertRedundantPublicAccessibility(.struct("RpmNestedNotUsedCrossModule")) {
            self.assertRedundantPublicAccessibility(.functionMethodInstance("rpmMemberOfRedundantNested()"))
        }
    }

    func testExtensionMembers() {
        analyze()

        assertRedundantPublicAccessibility(.functionMethodInstance("rpmInExtensionNotUsedCrossModule()"))
        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmInExtensionUsedCrossModule()"))
    }

    func testOpenClass() {
        analyze()

        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmOpenMember()"))
        assertRedundantPublicAccessibility(.functionMethodInstance("rpmPublicMemberOfOpenClass()"))
    }

    func testEnumCase() {
        analyze()

        assertNotRedundantPublicAccessibility(.enumelement("rpmCase"))
    }

    func testNothingReportedWhenDisabled() {
        index()

        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmNotUsedCrossModule()"))
        assertNotRedundantPublicAccessibility(.varInstance("rpmPropertyNotUsedCrossModule"))
        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmUsedByTestsOnly()"))
        assertNotRedundantPublicAccessibility(.struct("RpmNestedNotUsedCrossModule"))
        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmInExtensionNotUsedCrossModule()"))
        assertNotRedundantPublicAccessibility(.functionMethodInstance("rpmPublicMemberOfOpenClass()"))
    }

    // MARK: - Private

    private func analyze() {
        let configuration = Configuration()
        configuration.enableRedundantPublicMembers = true
        index(configuration: configuration)
    }
}
