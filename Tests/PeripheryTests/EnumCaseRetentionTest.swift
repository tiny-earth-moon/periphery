@testable import TestShared
import XCTest

final class EnumCaseRetentionTest: FixtureSourceGraphTestCase {
    func testRetainsCasesOfCaseIterableEnumUsingAllCases() {
        analyze(retainPublic: true) {
            assertReferenced(.enum("FixtureAllCasesUsedEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureAllCasesUsedCountEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureAllCasesUsedInArgumentEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureAllCasesNotUsedEnum")) {
                self.assertNotReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureAllCasesOnlyUsedByUnusedCodeEnum")) {
                self.assertNotReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureOuterCaseIterableEnum")) {
                self.assertNotReferenced(.enumelement("outer"))
                self.assertReferenced(.enum("Inner")) {
                    self.assertReferenced(.enumelement("first"))
                    self.assertReferenced(.enumelement("second"))
                }
            }
            assertReferenced(.enum("FixtureExplicitAllCasesEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureNotCaseIterableEnum")) {
                self.assertNotReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
        }
    }

    #if canImport(Testing)
        func testRetainsCasesUsedInSwiftTestingArguments() {
            analyze(retainPublic: true) {
                assertReferenced(.enum("FixtureTestArgumentEnum")) {
                    self.assertReferenced(.enumelement("first"))
                    self.assertReferenced(.enumelement("second"))
                }
            }
        }
    #endif

    func testRetainsCasesOfDecodableEnum() {
        analyze(retainPublic: true) {
            assertReferenced(.enum("FixtureDecodedEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureDecodedWithAssociatedValueEnum")) {
                self.assertReferenced(.enumelement("first(_:)"))
                self.assertReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureCodableEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureEncodableOnlyEnum")) {
                self.assertNotReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureNotDecodedEnum")) {
                self.assertNotReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
            assertReferenced(.enum("FixtureExplicitDecodableEnum")) {
                self.assertReferenced(.enumelement("first"))
                self.assertNotReferenced(.enumelement("second"))
            }
        }
    }

    func testRetainsEnumCasesWitnessingStaticRequirements() {
        analyze(retainPublic: true) {
            assertReferenced(.enum("FixtureThemeEnum")) {
                self.assertReferenced(.enumelement("fallback"))
                self.assertReferenced(.enumelement("dark"))
            }
            assertReferenced(.enum("FixtureBoxEnum")) {
                self.assertReferenced(.enumelement("make(_:)"))
                self.assertReferenced(.enumelement("other"))
            }
            assertReferenced(.enum("FixtureUnusedRequirementEnum")) {
                self.assertNotReferenced(.enumelement("fallback"))
                self.assertReferenced(.enumelement("dark"))
            }
        }
    }

    func testRetainsEnumCaseWitnessingStaticRequirementThroughSelf() {
        analyze(retainPublic: true) {
            assertReferenced(.enum("FixtureSelfDefaultableEnum")) {
                self.assertReferenced(.enumelement("initial"))
                self.assertNotReferenced(.enumelement("unusedCase"))
            }
        }
    }
}
