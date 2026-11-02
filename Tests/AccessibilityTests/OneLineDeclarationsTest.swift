import Configuration
@testable import TestShared
import XCTest

final class OneLineDeclarationsTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testEnumCaseResultDoesNotDependOnFormatting() {
        index()

        assertNotRedundantPublicAccessibility(.struct("OneLineCasePayload"))
        assertNotRedundantPublicAccessibility(.struct("MultiLineCasePayload"))
    }

    func testLabeledEnumCaseResultDoesNotDependOnFormatting() {
        index()

        assertNotRedundantPublicAccessibility(.struct("OneLineLabeledCasePayload"))
        assertNotRedundantPublicAccessibility(.struct("MultiLineLabeledCasePayload"))
    }

    func testSubscriptResultDoesNotDependOnFormatting() {
        index()

        assertNotRedundantPublicAccessibility(.struct("OneLineSubscriptResult"))
        assertNotRedundantPublicAccessibility(.struct("MultiLineSubscriptResult"))
    }

    func testTypealiasResultDoesNotDependOnFormatting() {
        index()

        assertNotRedundantPublicAccessibility(.struct("OneLineTypealiasTarget"))
        assertNotRedundantPublicAccessibility(.struct("MultiLineTypealiasTarget"))
    }

    func testTypeUsedOnlyInInternalMemberStaysRedundant() {
        index()

        assertRedundantPublicAccessibility(.struct("OneLineControlType"))
    }
}
