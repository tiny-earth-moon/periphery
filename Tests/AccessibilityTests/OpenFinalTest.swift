import Configuration
@testable import PeripheryKit
@testable import TestShared
import XCTest

final class OpenFinalTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testOpenClassSubclassedCrossModule() {
        analyze()

        assertNotRedundantOpenAccessibility(.class("OpenFinalClassSubclassedCrossModule")) {
            self.assertNotRedundantOpenAccessibility(.functionMethodInstance("openFinalOverriddenCrossModule()"))
            self.assertRedundantOpenAccessibility(.functionMethodInstance("openFinalNeverOverriddenMember()"))
        }
        assertNotMissingFinal(.class("OpenFinalClassSubclassedCrossModule"))
        assertNotMissingFinal(.class("OpenFinalCrossModuleSubclass"))
    }

    func testOpenClassNeverSubclassed() {
        analyze()

        assertRedundantOpenAccessibility(.class("OpenFinalClassNeverSubclassed")) {
            self.assertRedundantOpenAccessibility(.functionMethodInstance("openFinalMemberOfNeverSubclassedClass()"))
            self.assertNotMissingFinal(.functionMethodInstance("openFinalMemberOfNeverSubclassedClass()"))
        }
        assertNotMissingFinal(.class("OpenFinalClassNeverSubclassed"))
    }

    func testOpenMemberInPublicClass() {
        analyze()

        assertNotRedundantOpenAccessibility(.class("OpenFinalPublicClassWithOpenMember")) {
            self.assertRedundantOpenAccessibility(.functionMethodInstance("openFinalOpenMemberInPublicClass()"))
        }
    }

    func testInternalClassWithoutSubclass() {
        analyze()

        assertMissingFinal(.class("OpenFinalInternalClassWithoutSubclass")) {
            // Members of a class reported in full are not reported again.
            self.assertNotMissingFinal(.functionMethodInstance("openFinalMemberOfClassWithoutSubclass()"))
        }
    }

    func testInternalClassWithSubclass() {
        analyze()

        assertNotMissingFinal(.class("OpenFinalInternalClassWithSubclass")) {
            self.assertNotMissingFinal(.functionMethodInstance("openFinalOverriddenMember()"))
            self.assertMissingFinal(.functionMethodInstance("openFinalNotOverriddenMember()"))
            self.assertMissingFinal(.varInstance("openFinalVarProperty"))
            self.assertMissingFinal(.varInstance("openFinalComputedProperty"))
            // A constant cannot be overridden, final adds nothing.
            self.assertNotMissingFinal(.varInstance("openFinalLetProperty"))
        }
        assertNotMissingFinal(.class("OpenFinalInternalSubclass"))
    }

    func testAlreadyFinalClass() {
        analyze()

        assertNotMissingFinal(.class("OpenFinalAlreadyFinalClass")) {
            self.assertNotMissingFinal(.functionMethodInstance("openFinalMemberOfFinalClass()"))
        }
        assertNotRedundantOpenAccessibility(.class("OpenFinalAlreadyFinalClass"))
    }

    func testActor() {
        analyze()

        assertNotMissingFinal(.class("OpenFinalActor"))
    }

    func testNothingReportedWhenDisabled() {
        index()

        let openFinalResults = Self.results.filter {
            switch $0.annotation {
            case .redundantOpenAccessibility, .missingFinal: true
            default: false
            }
        }
        XCTAssertTrue(openFinalResults.isEmpty, "Unexpected results: \(openFinalResults.map(\.declaration))")
    }

    // MARK: - Private

    private func analyze() {
        let configuration = Configuration()
        configuration.enableOpenFinalAnalysis = true
        index(configuration: configuration)
    }
}
