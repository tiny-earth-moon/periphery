@testable import TestShared
import XCTest

final class RedundantPublicInlineArrayAndPackTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: AccessibilityProjectPath)
    }

    func testTypeUsedAsInlineArrayElementOfPublicDeclarationIsNotRedundant() {
        index()

        assertNotRedundantPublicAccessibility(.struct("InlineArrayReturnElement"))
        assertNotRedundantPublicAccessibility(.struct("InlineArrayParameterElement"))
        assertNotRedundantPublicAccessibility(.struct("InlineArrayVariableElement"))
    }

    func testTypeUsedInPackExpansionOfPublicDeclarationIsNotRedundant() {
        index()

        assertNotRedundantPublicAccessibility(.struct("PackReturnBox"))
        assertNotRedundantPublicAccessibility(.struct("PackParameterBox"))
    }

    func testTypeUsedAsInlineArrayElementOfInternalDeclarationStaysRedundant() {
        index()

        assertRedundantPublicAccessibility(.struct("InlineArrayInternalOnlyElement"))
    }
}
