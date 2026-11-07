import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
@testable import TestShared
import XCTest

final class UnconstructedEnumCaseTest: FixtureSourceGraphTestCase {
    func testReportsCasesOnlyMatched() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureMatchedState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("constructed"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedInSwitch"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedQualified"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedWithPayload(_:)"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedWithBinding(_:)"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedInIfCase"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedInGuardCase"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedInWhileCase"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedInForCase"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedOptional"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedInTuple"))
                self.assertEnumCaseNeverConstructed(.enumelement("matchedNested"))
            }
            assertReferenced(.enum("FixtureMatchedWrapper")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("wrapped(_:)"))
            }
            assertReferenced(.enum("FixtureMatchedError")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("thrown"))
                self.assertEnumCaseNeverConstructed(.enumelement("onlyCaught"))
            }
        }
    }

    func testConstructedCasesAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureConstructedState")) {
                for name in [
                    "initial", "assigned", "returned", "defaultArgument", "inClosure", "interpolated", "inResultBuilder", "inArray",
                    "passedAsArgument", "ternary", "comparedEqual", "comparedNotEqual", "functionValue(_:)", "payloadArgument(_:)",
                ] {
                    self.assertNotEnumCaseNeverConstructed(.enumelement(name))
                }
                // Control: the enum is analyzed.
                self.assertEnumCaseNeverConstructed(.enumelement("matchedOnly"))
            }
        }
    }

    func testCaseIterableEnumsAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureIterableState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
        }
    }

    func testRawValueEnumsAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureStringState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
            assertReferenced(.enum("FixtureIntState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
        }
    }

    func testDecodableEnumsAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureSynthesizedDecodableState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
            assertReferenced(.enum("FixtureCustomDecodableState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
            assertReferenced(.enum("FixtureCodableState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched(_:)"))
            }
        }
    }

    func testStaticRequirementCasesAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureRequirementState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("fallback"))
                self.assertNotEnumCaseNeverConstructed(.enumelement("make(_:)"))
                // Control: a case that satisfies no requirement is still reported.
                self.assertEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
            assertReferenced(.enum("FixtureExternalProtocolState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
        }
    }

    func testObjcEnumsAreNotReported() throws {
        #if !os(macOS)
            throw XCTSkip("@objc enums need the Objective-C runtime")
        #else
            analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
                assertReferenced(.enum("FixtureObjcState")) {
                    self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
                }
            }
        #endif
    }

    func testPublicEnumsAreNotReportedWhenRetained() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixturePublicState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
            // Control: an internal enum of the same module is reported.
            assertReferenced(.enum("FixtureInternalState")) {
                self.assertEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
        }
    }

    func testCrossModuleConstructedCasesAreNotReported() {
        let supportFile = FixturesProjectPath.appending("Sources/UnconstructedEnumCaseSupportFixtures/FixtureCrossModuleState.swift")

        analyze(
            retainPublicModules: ["UnconstructedEnumCaseFixtures"],
            enableUnconstructedEnumCaseAnalysis: true,
            additionalFilesToIndex: [supportFile]
        ) {
            module("UnconstructedEnumCaseSupportFixtures") {
                self.assertReferenced(.enum("FixtureCrossModuleState")) {
                    self.assertNotEnumCaseNeverConstructed(.enumelement("constructedElsewhere"))
                    // Control: a case matched in its module and constructed nowhere is reported.
                    self.assertEnumCaseNeverConstructed(.enumelement("onlyMatchedHere"))
                }
            }
        }
    }

    func testCustomPatternOperatorEnumsAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixturePatternOperatorState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("viaOperator"))
            }
        }
    }

    func testGenericPatternOperatorDisablesTheAnalysis() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureGenericOperatorState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("viaOperator"))
            }
        }
    }

    func testCasesNamedInConditionalBlocksAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureConditionalState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("constructedInInactiveClause"))
                // Control: a case named outside the `#if` block only is reported.
                self.assertEnumCaseNeverConstructed(.enumelement("matchedOnly"))
            }
        }
    }

    func testCasesNestedInPatternsOfOperatorEnumsAreNotReported() {
        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
            assertReferenced(.enum("FixtureOperatorInner")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyInWrappedPattern"))
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyInOptionalWrappedPattern"))
            }
        }
    }

    func testCasesConstructedInIndexExcludedFilesAreNotReported() {
        let excludedFile = FixturesProjectPath.appending("Sources/UnconstructedEnumCaseFixtures/FixtureExcludedStateFactory.swift")

        analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true, indexExcludedFiles: [excludedFile]) {
            assertReferenced(.enum("FixtureExcludedState")) {
                self.assertNotEnumCaseNeverConstructed(.enumelement("constructedInExcludedFile"))
                // Control: a case named in no excluded file is reported.
                self.assertEnumCaseNeverConstructed(.enumelement("matchedOnly"))
            }
        }
    }

    func testEnumsOfModulesExpandingMacrosAreNotReported() throws {
        #if !canImport(Testing)
            throw XCTSkip("The fixture expands a Swift Testing macro")
        #else
            analyze(retainPublic: true, enableUnconstructedEnumCaseAnalysis: true) {
                assertReferenced(.enum("FixtureMacroModuleState")) {
                    self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
                }
            }
        #endif
    }

    func testNothingReportedWithoutOption() {
        analyze(retainPublic: true) {
            assertReferenced(.enum("FixtureWithoutOptionState")) {
                self.assertReferenced(.enumelement("onlyMatched"))
                self.assertNotEnumCaseNeverConstructed(.enumelement("onlyMatched"))
            }
        }
    }

    func testOutputAndResultKind() throws {
        let file = SourceFile(path: FilePath("/App/State.swift"), modules: ["App"])
        let declaration = Declaration(name: "onlyMatched", kind: .enumelement, usrs: ["s:onlyMatched"], location: Location(file: file, line: 3, column: 10))
        let result = ScanResult(declaration: declaration, annotation: .enumCaseNeverConstructed)
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)

        let output = try XcodeFormatter(configuration: Configuration(), logger: logger).format([result], colored: false)

        XCTAssertEqual(output, "/App/State.swift:3:10: warning: Enum case 'onlyMatched' is only matched, never constructed")
        XCTAssertEqual(ResultKind.identifier(of: result), "enumCaseNeverConstructed.enumelement")
        XCTAssertTrue(ResultKind.isValid("enumCaseNeverConstructed.enumelement"))
    }
}
