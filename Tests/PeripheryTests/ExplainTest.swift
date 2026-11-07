import Configuration
@testable import PeripheryKit
import SystemPackage
@testable import TestShared
import XCTest

final class ExplainTest: FixtureSourceGraphTestCase {
    func testUnusedDeclarationExplainsAsUnused() {
        analyze("testNonReferencedClass", retainPublic: false)

        let explanation = explanation(of: "FixtureClass1")
        XCTAssertTrue(explanation.hasPrefix("FixtureClass1 (class at "), explanation)
        XCTAssertTrue(explanation.hasSuffix("is unused: no reference to it was found"), explanation)
    }

    func testUsedDeclarationPrintsTheReferenceChainFromARoot() {
        analyze("testExplainReferenceChain")

        let path = fixturePath("testExplainReferenceChain")
        XCTAssertEqual(explanation(of: "ExplainChainLeaf.finish()"), """
        ExplainChainLeaf.finish() (function at \(path):16:10) is used, through the reference chain:
            1. ExplainChainRoot (class at \(path):3:14): retained: PubliclyAccessibleRetainer, retain_public
            2. ExplainChainRoot.start() (function at \(path):4:17): retained within ExplainChainRoot: PubliclyAccessibleRetainer, retain_public
            3. ExplainChainMiddle.step() (function at \(path):10:10): referenced at \(path):5:30
            4. ExplainChainLeaf.finish() (function at \(path):16:10): referenced at \(path):11:28
        """)
    }

    func testRetainPublicDeclarationNamesPubliclyAccessibleRetainer() {
        analyze("testExplainReferenceChain")

        XCTAssertEqual(
            explanation(of: "ExplainChainRoot"),
            "ExplainChainRoot (class at \(fixturePath("testExplainReferenceChain")):3:14) is retained: PubliclyAccessibleRetainer, retain_public"
        )
    }

    func testCommentCommandRetentionPrintsItsReason() {
        analyze("testIgnoreComments")

        let explanation = explanation(of: "Fixture113.someFunc(param:)")
        XCTAssertTrue(
            explanation.contains("is retained: CommentCommand, outskirts:ignore (or periphery:ignore) on the declaration or an enclosing one"),
            explanation
        )
    }

    func testPlatformConditionalRetentionPrintsTheNameAndItsLocation() {
        analyze("testRetainsDeclarationsReferencedInPlatformConditionalBlocks")

        let path = fixturePath("testRetainsDeclarationsReferencedInPlatformConditionalBlocks")
        let explanation = explanation(of: "onlyUsedOnWindows()")
        XCTAssertTrue(
            explanation.contains("is retained: PlatformConditionalRetainer, name 'onlyUsedOnWindows' written in #elseif os(Windows) at \(path):15"),
            explanation
        )
    }

    func testProtocolWitnessPrintsTheRequirementItImplements() {
        analyze("testProtocolConformingMembersAreRetained")

        let explanation = explanation(of: "FixtureClass27.protocolMethod()")
        XCTAssertTrue(explanation.contains("is used, through the reference chain:"), explanation)
        XCTAssertTrue(explanation.hasSuffix(": protocol witness of the requirement FixtureProtocol27.protocolMethod()"), explanation)
    }

    func testReportedDeclarationExplainsItsDiscardedSelfReference() {
        analyze("testSelfReferencedRecursiveMethod")

        let lines = explanation(of: "recursive()").split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 2, lines.joined(separator: "\n"))
        XCTAssertTrue(lines.first?.hasSuffix("is reported as unused: no reference to it is reached from a root") == true, lines.joined(separator: "\n"))
        XCTAssertTrue(lines.last?.hasSuffix("in FixtureClass9.recursive(): self-reference, written inside the declaration it refers to") == true, lines.joined(separator: "\n"))
    }

    func testFileLineAndUnknownQueries() {
        analyze("testExplainReferenceChain")

        let explanation = explanation(of: "testExplainReferenceChain.swift:16")
        XCTAssertTrue(explanation.hasPrefix("ExplainChainLeaf.finish() (function at "), explanation)
        XCTAssertEqual(self.explanation(of: "NoSuchDeclaration"), "No declaration matches 'NoSuchDeclaration'.")
    }

    func testScanWithoutExplainRecordsNothingAndReportsTheSameResults() {
        analyze("testRetainsDeclarationsReferencedInPlatformConditionalBlocks")
        let explainedResults = describe(Self.results)
        XCTAssertGreaterThan(recordedExplanationEntryCount, 0)

        analyze("testRetainsDeclarationsReferencedInPlatformConditionalBlocks", explain: false)
        XCTAssertEqual(recordedExplanationEntryCount, 0)
        XCTAssertEqual(describe(Self.results), explainedResults)
        XCTAssertFalse(explainedResults.isEmpty)
    }

    // MARK: - Private

    private func analyze(_ fixture: String, retainPublic: Bool = true, explain: Bool = true) {
        let configuration = Configuration()
        configuration.retainPublic = retainPublic
        configuration.explain = explain ? [fixture] : []
        configuration.buildFilenameMatchers()
        Self.index(sourceFiles: [FilePath(fixturePath(fixture))], configuration: configuration)
    }

    private func fixturePath(_ fixture: String) -> String {
        FixturesProjectPath.appending("Sources/RetentionFixtures/\(fixture).swift").string
    }

    private func describe(_ results: [ScanResult]) -> [String] {
        results.map { "\($0.declaration.kind) \($0.declaration.name) \($0.declaration.location) \($0.annotation)" }.sorted()
    }
}
