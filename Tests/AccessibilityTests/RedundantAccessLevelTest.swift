import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

final class RedundantAccessLevelTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testNothingReportedWhenDisabled() {
        index()

        let redundantAccessLevelResults = Self.results.filter {
            if case .redundantAccessLevel = $0.annotation {
                return true
            }
            return false
        }
        XCTAssertTrue(redundantAccessLevelResults.isEmpty, "Unexpected results: \(redundantAccessLevelResults.map(\.declaration))")
    }

    func testTopLevel() {
        analyze()

        assertRedundantAccessLevel(.functionFree("ralInternalTopLevelFunction()"))
        assertNotRedundantAccessLevel(.functionFree("ralImplicitTopLevelFunction()"))
        assertNotRedundantAccessLevel(.functionFree("ralFileprivateTopLevelFunction()"))
        assertRedundantAccessLevel(.extensionStruct("RalInternalExtended"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralImplicitInInternalExtension()"))
    }

    func testPublicType() {
        analyze()

        assertNotRedundantAccessLevel(.struct("RalPublicStruct"))
        assertRedundantAccessLevel(.functionMethodInstance("ralInternalInPublicStruct()"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralPublicInPublicStruct()"))
        assertRedundantAccessLevel(.functionMethodStatic("ralInternalInPublicEnum()"))
        assertNotRedundantAccessLevel(.enumelement("ralCase"))
    }

    func testOpenClass() {
        analyze()

        assertNotRedundantAccessLevel(.class("RalOpenClass"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralOpenInOpenClass()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralInternalInOpenClass()"))
    }

    func testInternalType() {
        analyze()

        assertRedundantAccessLevel(.varInstance("ralInternalInInternalStruct"))
        assertNotRedundantAccessLevel(.varInstance("ralPrivateInInternalStruct"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralFileprivateInInternalStruct()"))
    }

    func testSetterAccessModifier_isNotTheDeclarationAccessLevel() {
        analyze()

        assertNotRedundantAccessLevel(.varInstance("ralInternalSetterVar"))
        assertNotRedundantAccessLevel(.varInstance("ralPublicVarWithInternalSetter"))
    }

    func testPrivateAndFileprivateTypes() {
        analyze()

        assertRedundantAccessLevel(.functionMethodInstance("ralFileprivateInPrivateStruct()"))
        // A private member is narrower than the type's default: visible to the type's declarations only.
        assertNotRedundantAccessLevel(.functionMethodInstance("ralPrivateInPrivateStruct()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralFileprivateInNestedOfPrivateStruct()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralFileprivateInFileprivateStruct()"))
        // Members of a private nested type default to the enclosing scope, which no modifier expresses.
        assertNotRedundantAccessLevel(.functionMethodInstance("ralFileprivateInPrivateNestedStruct()"))
    }

    func testExtensions() {
        analyze()

        assertRedundantAccessLevel(.functionMethodInstance("ralInternalInImplicitExtension()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralPublicInPublicExtension()"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralInternalInPublicExtension()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralPrivateInPrivateExtension()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralFileprivateInPrivateExtension()"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralPrivateInFileprivateExtension()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralPublicInPublicProtocolExtension()"))
        assertNotRedundantAccessLevel(.functionMethodInstance("ralProtocolRequirement()"))
        assertRedundantAccessLevel(.functionMethodInstance("ralInternalInExternalTypeExtension()"))
    }

    // MARK: - Private

    private func analyze() {
        let configuration = Configuration()
        configuration.enableRedundantAccessLevelAnalysis = true
        index(configuration: configuration)
    }
}
