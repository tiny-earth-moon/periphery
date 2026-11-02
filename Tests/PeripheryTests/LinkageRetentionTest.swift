import SystemPackage
@testable import TestShared
import XCTest

#if os(macOS)
    final class LinkageRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsCdeclFunction() {
            analyze {
                assertReferenced(.functionFree("exportedWithCdecl()"))
                assertNotReferenced(.functionFree("plainAfterCdecl()"))
            }
        }

        func testRetainsCFunction() {
            analyze {
                assertReferenced(.functionFree("exportedWithC()"))
                assertReferenced(.functionFree("exportedWithNamedC()"))
                assertNotReferenced(.functionFree("plainAfterC()"))
            }
        }

        func testRetainsSilgenNameDefinition() {
            analyze {
                assertReferenced(.functionFree("definedWithSilgenName()"))
                assertNotReferenced(.functionFree("plainAfterSilgenName()"))
            }
        }

        func testRetainsUsedGlobal() {
            analyze {
                assertReferenced(.globalVar("keptGlobal"))
                assertReferenced(.functionFree("keptFunction()"))
                assertNotReferenced(.globalVar("plainGlobalAfterUsed"))
            }
        }

        func testRetainsSectionGlobal() {
            analyze {
                assertReferenced(.globalVar("sectionOnly"))
                assertReferenced(.globalVar("sectionAndUsed"))
                assertNotReferenced(.globalVar("plainGlobalAfterSection"))
            }
        }

        func testReportsBodylessSilgenNameDeclaration() {
            analyze {
                assertNotReferenced(.functionFree("importedUnusedWithSilgenName(_:_:)"))
            }
        }

        func testRetainsParametersOfBodylessDeclarations() {
            analyze {
                assertReferenced(.functionFree("importedWithSilgenName(_:_:)")) {
                    self.assertUsedParameter("first")
                    self.assertUsedParameter("second")
                }
                assertReferenced(.functionFree("importedWithExtern(_:)")) {
                    self.assertUsedParameter("value")
                }
                // Control: a function with a body still reports its unused parameters.
                assertReferenced(.functionFree("definedWithUnusedParameter(_:)")) {
                    self.assertNotReferenced(.varParameter("value"))
                }
            }
        }
    }

    private extension DeclarationDescription {
        static func globalVar(_ name: String) -> Self {
            self.init(kind: .varGlobal, name: name, line: nil)
        }
    }
#endif
