import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
@testable import TestShared
import XCTest

final class UnassignedOptionalTest: FixtureSourceGraphTestCase {
    func testReportsUnassignedOptionals() {
        analyze(retainPublic: true, enableUnassignedOptionalAnalysis: true) {
            assertReferenced(.class("FixtureUnassignedOptionalRead")) {
                self.assertUnassignedOptionalProperty(.varStatic("sharedNeverAssigned"))
                self.assertUnassignedOptionalProperty(.varInstance("neverAssigned"))
                self.assertUnassignedOptionalProperty(.varInstance("neverAssignedImplicitlyUnwrapped"))
                self.assertUnassignedOptionalProperty(.varInstance("neverAssignedGeneric"))
                self.assertUnassignedOptionalProperty(.varInstance("nilInitialized"))
            }
        }
    }

    func testXcodeOutputAndResultKind() throws {
        let file = SourceFile(path: FilePath("/App/Foo.swift"), modules: ["App"])
        let declaration = Declaration(name: "someVar", kind: .varInstance, usrs: ["s:someVar"], location: Location(file: file, line: 2, column: 9))
        let result = ScanResult(declaration: declaration, annotation: .unassignedOptionalProperty)
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)

        let output = try XcodeFormatter(configuration: Configuration(), logger: logger).format([result], colored: false)

        XCTAssertEqual(output, "/App/Foo.swift:2:9: warning: Optional property 'someVar' is never assigned (always nil)")
        XCTAssertEqual(ResultKind.identifier(of: result), "unassignedOptionalProperty.var.instance")
        XCTAssertTrue(ResultKind.isValid("unassignedOptionalProperty"))
    }

    func testNothingReportedWithoutOption() {
        analyze(retainPublic: true) {
            assertReferenced(.class("FixtureUnassignedOptionalWithoutOption")) {
                self.assertReferenced(.varInstance("neverAssigned"))
                self.assertNotUnassignedOptionalProperty(.varInstance("neverAssigned"))
            }
        }
    }

    func testAssignedOptionalsAreNotReported() {
        analyze(retainPublic: true, enableUnassignedOptionalAnalysis: true) {
            assertReferenced(.class("FixtureUnassignedOptionalAssigned")) {
                self.assertNotUnassignedOptionalProperty(.varInstance("assignedInInit"))
                self.assertNotUnassignedOptionalProperty(.varInstance("assignedInMethod"))
                self.assertNotUnassignedOptionalProperty(.varInstance("assignedViaSelfInMethod"))
                self.assertNotUnassignedOptionalProperty(.varInstance("assignedInClosure"))
                self.assertNotUnassignedOptionalProperty(.varInstance("assignedViaInout"))
                self.assertNotUnassignedOptionalProperty(.varInstance("assignedViaKeyPath"))
                self.assertNotUnassignedOptionalProperty(.varInstance("withInitialValue"))
                self.assertNotUnassignedOptionalProperty(.varInstance("nonOptional"))
                self.assertNotUnassignedOptionalProperty(.varInstance("constant"))
            }
        }
    }

    func testRuntimeAssignedOptionalsAreNotReported() {
        analyze(retainPublic: true, enableUnassignedOptionalAnalysis: true) {
            assertReferenced(.struct("FixtureUnassignedOptionalDecodableStruct")) {
                self.assertNotUnassignedOptionalProperty(.varInstance("decoded"))
            }
            assertReferenced(.class("FixtureUnassignedOptionalDecodableClass")) {
                self.assertNotUnassignedOptionalProperty(.varInstance("decoded"))
            }
            assertReferenced(.class("FixtureUnassignedOptionalCoding")) {
                self.assertNotUnassignedOptionalProperty(.varInstance("decoded"))
            }
            assertReferenced(.class("FixtureUnassignedOptionalRuntime")) {
                self.assertNotUnassignedOptionalProperty(.varInstance("weakReference"))
                self.assertNotUnassignedOptionalProperty(.varInstance("wrapped"))
            }
            #if os(macOS)
                assertReferenced(.class("FixtureUnassignedOptionalInterfaceBuilder")) {
                    self.assertNotUnassignedOptionalProperty(.varInstance("outlet"))
                    self.assertNotUnassignedOptionalProperty(.varInstance("objcProperty"))
                    self.assertNotUnassignedOptionalProperty(.varInstance("dynamicProperty"))
                }
            #endif
        }
    }
}
