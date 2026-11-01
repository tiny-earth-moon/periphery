import SystemPackage
@testable import TestShared
import XCTest

#if os(macOS)
    final class ObjcAccessibleRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsOptionalProtocolMethodImplementedInSubclass() throws {
            try XCTSkipIf(Self.swiftVersion.version.isVersion(lessThan: "6.3"), "Requires Swift >= 6.3")
            analyze(retainPublic: true) {
                assertReferenced(.class("FixtureClass125Base"))
                assertReferenced(.class("FixtureClass125")) {
                    self.assertReferenced(.functionMethodInstance("fileManager(_:shouldRemoveItemAtPath:)"))
                }
            }
        }

        func testRetainsOptionalProtocolMethod() {
            analyze(retainPublic: true) {
                assertReferenced(.class("FixtureClass127")) {
                    self.assertReferenced(.functionMethodInstance("someFunc()"))
                }
                assertReferenced(.protocol("FixtureProtocol127")) {
                    self.assertReferenced(.functionMethodInstance("optionalFunc()"))
                }
            }
        }

        func testRetainsObjcAnnotatedClass() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass21"))
            }
        }

        func testRetainsImplicitlyObjcAccessibleClass() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass126"))
            }
        }

        func testRetainsObjcAnnotatedMembers() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass22")) {
                    self.assertReferenced(.varInstance("someVar"))
                    self.assertReferenced(.functionMethodInstance("someMethod()"))
                    self.assertReferenced(.functionMethodInstance("somePrivateMethod()"))
                }
            }
        }

        func testDoesNotRetainObjcAnnotatedWithoutOption() {
            analyze(retainPublic: true) {
                assertNotReferenced(.class("FixtureClass23"))
            }
        }

        func testDoesNotRetainMembersOfObjcAnnotatedClass() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass24")) {
                    self.assertNotReferenced(.functionMethodInstance("someMethod()"))
                    self.assertNotReferenced(.varInstance("someVar"))
                }
            }
        }

        func testObjcMembersAnnotationRetainsMembers() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass25")) {
                    self.assertReferenced(.varInstance("someVar"))
                    self.assertReferenced(.functionMethodInstance("someMethod()"))
                    self.assertNotReferenced(.functionMethodInstance("somePrivateMethod()"))
                }
            }
        }

        func testRetainsJSExportProtocols() {
            analyze(retainPublic: true) {
                assertReferenced(.protocol("FixtureProtocolJSExport")) {
                    self.assertNotReferenced(.functionMethodInstance("exported()"))
                }
                assertReferenced(.protocol("FixtureProtocolJSExportIntermediate")) {
                    self.assertNotReferenced(.varInstance("intermediateValue"))
                }
                assertReferenced(.class("FixtureClassJSExport")) {
                    self.assertNotReferenced(.functionMethodInstance("exported()"))
                    self.assertNotReferenced(.varInstance("intermediateValue"))
                    self.assertNotReferenced(.functionMethodInstance("notExported()"))
                    self.assertNotReferenced(.functionMethodInstance("witness()"))
                }
            }

            analyze(retainPublic: true, retainJsAccessible: true) {
                assertReferenced(.protocol("FixtureProtocolJSExport")) {
                    self.assertReferenced(.functionMethodInstance("exported()"))
                }
                assertReferenced(.protocol("FixtureProtocolJSExportIntermediate")) {
                    self.assertReferenced(.varInstance("intermediateValue"))
                }
                assertReferenced(.class("FixtureClassJSExport")) {
                    self.assertReferenced(.functionMethodInstance("exported()"))
                    self.assertReferenced(.varInstance("intermediateValue"))
                    self.assertNotReferenced(.functionMethodInstance("notExported()"))
                    self.assertNotReferenced(.functionMethodInstance("witness()"))
                }
            }
        }
    }
#endif
