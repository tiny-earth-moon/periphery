@testable import TestShared
import XCTest

// The fixture needs Swift 6.2 (InlineArray) and is left out of the fixture package on older toolchains.
#if compiler(>=6.2)
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
#endif
