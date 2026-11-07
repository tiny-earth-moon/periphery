@testable import Fix
import Foundation
import SourceGraph
import SystemPackage
import XCTest

/// Golden before and after buffers of every tier-1 rule of `outskirts fix`, and the cases it refuses.
final class FixCommandTest: XCTestCase {
    private var directory: FilePath!

    override func setUpWithError() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-fix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        directory = FilePath(url.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Redundant public, open and access level

    func testRedundantPublicDeletesTheModifierAndItsTrailingSpaceOnly() throws {
        let source = """
        /// Renders.
        @inlinable public func render() {}
        public private(set) var count = 0
        """
        let fixed = try fix(source, [
            target(.redundantPublic, "render()", .functionFree, at: "render", in: source),
            target(.redundantPublic, "count", .varGlobal, at: "count", in: source),
        ])

        XCTAssertEqual(fixed, """
        /// Renders.
        @inlinable func render() {}
        private(set) var count = 0
        """)
    }

    func testRedundantOpenBecomesPublic() throws {
        let source = "open class Base {\n    open func run() {}\n}\n"
        let fixed = try fix(source, [
            target(.redundantOpen, "Base", .class, at: "Base", in: source),
            target(.redundantOpen, "run()", .functionMethodInstance, at: "run", in: source),
        ])

        XCTAssertEqual(fixed, "public class Base {\n    public func run() {}\n}\n")
    }

    func testRedundantAccessLevelKeepsTheCommentsAroundTheModifier() throws {
        let source = "struct S {\n    // Kept.\n    internal /* kept */ func run() {}\n}\n"
        let fixed = try fix(source, [
            target(.redundantAccessLevel, "run()", .functionMethodInstance, at: "run", in: source, accessibility: .internal),
        ])

        XCTAssertEqual(fixed, "struct S {\n    // Kept.\n    /* kept */ func run() {}\n}\n")
    }

    func testModifierOfADeclarationWithSeveralBindingsIsSkipped() throws {
        let source = "public var a = 1, b = 2\n"
        let plan = try planned(source, [target(.redundantPublic, "a", .varGlobal, at: "a =", in: source)])

        XCTAssertEqual(plan.skipped.map(\.reason), [.multipleBindings])
        XCTAssertTrue(plan.changes.isEmpty)
    }

    // MARK: - Empty extensions

    func testEmptyExtensionTakesItsDocCommentButNotTheCommentBlockAbove() throws {
        let source = """
        // Copyright header.

        struct Widget {}

        // MARK: - Helpers

        /// Doc of the extension.
        @available(macOS 15, *)
        extension Widget {}

        struct Other {}

        """
        let fixed = try fix(source, [target(.emptyExtension, "Widget", .extension, at: "Widget {}\n\nstruct Other", in: source)])

        XCTAssertEqual(fixed, """
        // Copyright header.

        struct Widget {}

        // MARK: - Helpers

        struct Other {}

        """)
    }

    func testEmptyExtensionOfANestedTypeAndInsideAConditionalBlock() throws {
        let source = """
        enum Outer { struct Inner {} }

        extension Outer.Inner {}

        #if DEBUG
        extension Outer {
            #if os(macOS)
            #endif
        }
        #endif

        """
        let fixed = try fix(source, [
            target(.emptyExtension, "Outer.Inner", .extension, at: "Outer.Inner {}", in: source),
            target(.emptyExtension, "Outer", .extension, at: "Outer {\n", in: source),
        ])

        XCTAssertEqual(fixed, """
        enum Outer { struct Inner {} }

        #if DEBUG
        #endif

        """)
    }

    func testModifierEditInsideARemovedExtensionCollapsesIntoIt() throws {
        let source = "struct S {}\npublic extension S {}\n"
        let plan = try planned(source, [
            target(.redundantPublic, "S", .extensionStruct, at: "S {}\n", in: source, occurrence: 2),
            target(.emptyExtension, "S", .extension, at: "S {}\n", in: source, occurrence: 2),
        ])

        XCTAssertEqual(plan.applied.count, 2)
        XCTAssertTrue(plan.skipped.isEmpty)
        XCTAssertEqual(try apply(plan), "struct S {}\n")
    }

    func testExtensionWithAConformanceIsNotRemoved() throws {
        let source = "struct S {}\nextension S: Sendable {}\n"
        let plan = try planned(source, [target(.emptyExtension, "S", .extension, at: "S: Sendable", in: source)])

        XCTAssertEqual(plan.skipped.map(\.reason), [.extensionNotEmpty])
    }

    // MARK: - Unused imports

    func testUnusedImportKeepsTheFileHeaderAndTakesItsOwnComments() throws {
        let source = """
        // File header.

        import Foundation
        /// Why this import.
        import Dispatch // trailing note
        import os

        let x = 1
        """
        let fixed = try fix(source, [
            target(.unusedImport, "Dispatch", .module, at: "import Dispatch", in: source),
            target(.unusedImport, "os", .module, at: "import os", in: source),
        ])

        XCTAssertEqual(fixed, """
        // File header.

        import Foundation

        let x = 1
        """)
    }

    func testUnusedImportSharingALineWithAnotherStatement() throws {
        let source = "import A; import B\nlet x = 1\n"
        let fixed = try fix(source, [target(.unusedImport, "B", .module, at: "import B", in: source)])

        XCTAssertEqual(fixed, "import A;\nlet x = 1\n")
    }

    func testConditionalTestableAndExportedImportsAreSkipped() throws {
        let source = """
        #if canImport(UIKit)
        import UIKit
        #endif
        @testable import Lib
        @_exported import Core
        public import Kit

        """
        let plan = try planned(source, [
            target(.unusedImport, "UIKit", .module, at: "import UIKit", in: source),
            target(.unusedImport, "Lib", .module, at: "@testable", in: source),
            target(.unusedImport, "Core", .module, at: "@_exported", in: source),
            target(.unusedImport, "Kit", .module, at: "public import", in: source),
        ])

        XCTAssertEqual(plan.skipped.map(\.reason), [.conditionalImport, .testableImport, .exportedImport, .exportedImport])
        XCTAssertTrue(plan.changes.isEmpty)
    }

    // MARK: - Superfluous ignore comments

    func testSuperfluousIgnoreCommentsAreRemoved() throws {
        let source = """
        struct S {
            // periphery:ignore
            func a() {}
            func b() {} // outskirts:ignore - kept for now
            /// Doc stays.
            // periphery:ignore:parameters x,y
            func c(x: Int, y: Int) {}
        }
        """
        let fixed = try fix(source, [
            target(.superfluousIgnore, "a()", .functionMethodInstance, at: "a()", in: source),
            target(.superfluousIgnore, "b()", .functionMethodInstance, at: "b()", in: source),
            target(.superfluousIgnore, "x", .varParameter, at: "c(", in: source),
            target(.superfluousIgnore, "y", .varParameter, at: "c(", in: source),
        ])

        XCTAssertEqual(fixed, """
        struct S {
            func a() {}
            func b() {}
            /// Doc stays.
            func c(x: Int, y: Int) {}
        }
        """)
    }

    func testParameterIgnoreThatStillCoversAnUnusedParameterIsKept() throws {
        let source = "// periphery:ignore:parameters x,y\nfunc c(x: Int, y: Int) {}\n"
        let plan = try planned(source, [target(.superfluousIgnore, "x", .varParameter, at: "c(", in: source)])

        XCTAssertEqual(plan.skipped.map(\.reason), [.partialParameterIgnore])
    }

    // MARK: - Unused parameters

    func testUnusedParameterKeepsTheArgumentLabel() throws {
        let source = """
        func f(a: Int, _ b: Int, label c: Int, _ d: Int = 0) {}
        struct S {
            init(value: Int) {}
            subscript(index: Int) -> Int { 0 }
            static func + (lhs: S, rhs: S) -> S { lhs }
        }
        """
        let fixed = try fix(source, [
            target(.unusedParameter, "a", .varParameter, at: "a:", in: source),
            target(.unusedParameter, "b", .varParameter, at: "b:", in: source),
            target(.unusedParameter, "c", .varParameter, at: "c:", in: source),
            target(.unusedParameter, "d", .varParameter, at: "d:", in: source),
            target(.unusedParameter, "value", .varParameter, at: "value:", in: source),
            target(.unusedParameter, "index", .varParameter, at: "index:", in: source),
            target(.unusedParameter, "rhs", .varParameter, at: "rhs:", in: source),
        ])

        XCTAssertEqual(fixed, """
        func f(a _: Int, _: Int, label _: Int, _: Int = 0) {}
        struct S {
            init(value _: Int) {}
            subscript(_: Int) -> Int { 0 }
            static func + (lhs: S, _: S) -> S { lhs }
        }
        """)
    }

    // MARK: - Missing final (tier 2)

    func testMissingFinalGoesAfterTheAttributesAndTheAccessModifier() throws {
        let source = """
        class Plain {}
        public class Public {}
        @MainActor
        internal class Annotated {}
        @objc(Bridged) private class Bridged: NSObject {}
        /// Doc.
        @available(macOS 15, *) fileprivate /* kept */ class Commented {}
        struct Outer {
            package class Nested {
                class Inner {}
            }
        }

        """
        let fixed = try fix(source, [
            target(.missingFinal, "Plain", .class, at: "Plain", in: source),
            target(.missingFinal, "Public", .class, at: "Public", in: source),
            target(.missingFinal, "Annotated", .class, at: "Annotated", in: source),
            target(.missingFinal, "Bridged", .class, at: "Bridged:", in: source),
            target(.missingFinal, "Commented", .class, at: "Commented", in: source),
            target(.missingFinal, "Nested", .class, at: "Nested", in: source),
            target(.missingFinal, "Inner", .class, at: "Inner", in: source),
        ])

        XCTAssertEqual(fixed, """
        final class Plain {}
        public final class Public {}
        @MainActor
        internal final class Annotated {}
        @objc(Bridged) private final class Bridged: NSObject {}
        /// Doc.
        @available(macOS 15, *) fileprivate /* kept */ final class Commented {}
        struct Outer {
            package final class Nested {
                final class Inner {}
            }
        }

        """)
    }

    func testMissingFinalWithARedundantAccessModifierOnTheSameClass() throws {
        let source = "public class A {}\ninternal class B {}\n"
        let fixed = try fix(source, [
            target(.missingFinal, "A", .class, at: "A {}", in: source),
            target(.redundantPublic, "A", .class, at: "A {}", in: source),
            target(.missingFinal, "B", .class, at: "B {}", in: source),
            target(.redundantAccessLevel, "B", .class, at: "B {}", in: source, accessibility: .internal),
        ])

        XCTAssertEqual(fixed, "final class A {}\nfinal class B {}\n")
    }

    func testFinalAndOpenClassesAreLeftUntouched() throws {
        let source = "public final class Done {}\nfinal public class Reversed {}\nopen class Base {}\nactor Worker {}\n"
        let plan = try planned(source, [
            target(.missingFinal, "Done", .class, at: "Done", in: source),
            target(.missingFinal, "Reversed", .class, at: "Reversed", in: source),
            target(.missingFinal, "Base", .class, at: "Base", in: source),
            target(.missingFinal, "Worker", .class, at: "Worker", in: source),
        ])

        XCTAssertEqual(plan.skipped.map(\.reason), [.alreadyFinal, .alreadyFinal, .openClass, .locationMismatch])
        XCTAssertTrue(plan.changes.isEmpty)
    }

    func testMissingFinalSecondRunProducesNoChange() throws {
        let source = "@MainActor public class A {\n    class B {}\n}\n"
        let targets = [
            target(.missingFinal, "A", .class, at: "A {", in: source),
            target(.missingFinal, "B", .class, at: "B {}", in: source),
        ]
        let fixed = try fix(source, targets)
        XCTAssertEqual(fixed, "@MainActor public final class A {\n    final class B {}\n}\n")

        let secondPlan = makePlanner().plan([
            target(.missingFinal, "A", .class, at: "A {", in: fixed),
            target(.missingFinal, "B", .class, at: "B {}", in: fixed),
        ])
        XCTAssertTrue(secondPlan.changes.isEmpty)
        XCTAssertEqual(secondPlan.skipped.map(\.reason), [.alreadyFinal, .alreadyFinal])
    }

    func testMissingFinalIsATierTwoRuleOfTheOpenFinalAnalysis() {
        XCTAssertEqual(FixRule.allCases.filter(\.isAggressive), [.missingFinal])
    }

    // MARK: - Restoring the original buffers

    func testRestoreWritesBackTheOriginalBytesOfTheFilesThatStillHoldTheFixes() throws {
        let source = "\u{FEFF}import A\nimport B\n\n"
        let plan = try planned(source, [target(.unusedImport, "B", .module, at: "import B", in: source)])
        XCTAssertEqual(plan.changes.count, 1)
        let other = directory.appending("Other.swift")
        try Data("import C\n".utf8).write(to: URL(fileURLWithPath: other.string))
        let otherPlan = makePlanner().plan([FixTarget(rule: .unusedImport, name: "C", kind: .module, file: other, line: 1, column: 1)])
        try FixWriter.apply(plan)
        try FixWriter.apply(otherPlan)
        try Data("// edited after the fixes\n".utf8).write(to: URL(fileURLWithPath: other.string))

        let restoration = FixWriter.restore(plan)
        let otherRestoration = FixWriter.restore(otherPlan)

        XCTAssertEqual(restoration.restored, [file])
        XCTAssertEqual(try [UInt8](Data(contentsOf: URL(fileURLWithPath: file.string))), Array(source.utf8))
        XCTAssertEqual(otherRestoration.notRestored, [other])
        XCTAssertEqual(try String(contentsOfFile: other.string, encoding: .utf8), "// edited after the fixes\n")
        XCTAssertEqual(restoration.summary(relativeTo: directory, changeCount: 1), "The fixes break the build, restored 1 of 1 file:\n  restored File.swift")
    }

    // MARK: - Diff, idempotence and trivia

    func testDryRunPrintsAUnifiedDiffAndLeavesTheFileUntouched() throws {
        let source = "import A\nimport B\n\nfunc f(a: Int) {}\n"
        let plan = try planned(source, [
            target(.unusedImport, "B", .module, at: "import B", in: source),
            target(.unusedParameter, "a", .varParameter, at: "a:", in: source),
        ])

        let expectedDiff = [
            "--- a/File.swift",
            "+++ b/File.swift",
            "@@ -1,4 +1,3 @@",
            " import A",
            "-import B",
            " ",
            "-func f(a: Int) {}",
            "+func f(a _: Int) {}",
            "",
        ].joined(separator: "\n")
        XCTAssertEqual(plan.diff(relativeTo: directory), expectedDiff)
        XCTAssertEqual(try String(contentsOfFile: file.string, encoding: .utf8), source)
    }

    func testSecondRunProducesNoDiff() throws {
        let source = "/// Doc.\npublic func f(a: Int) {}\nextension Int {}\n"
        let targets = [
            target(.redundantPublic, "f(a:)", .functionFree, at: "f(", in: source),
            target(.unusedParameter, "a", .varParameter, at: "a:", in: source),
            target(.emptyExtension, "Int", .extension, at: "Int {}", in: source),
        ]
        let fixed = try fix(source, targets)
        XCTAssertEqual(fixed, "/// Doc.\nfunc f(a _: Int) {}\n")

        let secondPlan = makePlanner().plan(targets)
        XCTAssertTrue(secondPlan.changes.isEmpty)
        XCTAssertEqual(Set(secondPlan.skipped.map(\.reason)), [.locationMismatch])
    }

    func testOverlappingEditsAreRefusedAndNestedEditsCollapse() {
        let outer = SourceEdit(range: 0 ..< 10)
        let nested = SourceEdit(range: 2 ..< 4, replacement: "x")
        let crossing = SourceEdit(range: 8 ..< 12)
        let separate = SourceEdit(range: 20 ..< 21)

        let resolution = EditResolution([0: [outer], 1: [nested], 2: [crossing], 3: [separate]])

        XCTAssertEqual(resolution.refusedOwners, [0, 2])
        XCTAssertEqual(resolution.edits, [nested, separate])
    }

    func testInsertionAtTheStartOfADeletionIsAppliedBeforeIt() {
        let deletion = SourceEdit(range: 2 ..< 5)
        let insertion = SourceEdit(range: 2 ..< 2, replacement: "X")

        let resolution = EditResolution([0: [deletion], 1: [insertion]])

        XCTAssertEqual(resolution.edits, [insertion, deletion])
        XCTAssertEqual(resolution.apply(to: Array("abcdefg".utf8)), Array("abXfg".utf8))
    }

    func testByteOrderMarkDoesNotShiftTheEdits() throws {
        let source = "\u{FEFF}import A\nimport B\nfunc f(a: Int) {}\n"
        let fixed = try fix(source, [
            target(.unusedImport, "B", .module, at: "import B", in: source),
            target(.unusedParameter, "a", .varParameter, at: "a:", in: source),
        ])

        XCTAssertEqual(fixed, "\u{FEFF}import A\nfunc f(a _: Int) {}\n")
    }

    // MARK: - Refusals

    func testLocationMismatchIsSkipped() throws {
        let source = "public func render() {}\n"
        let plan = try planned(source, [
            target(.redundantPublic, "draw()", .functionFree, at: "render", in: source),
            target(.redundantPublic, "render()", .functionFree, at: "func", in: source),
            target(.redundantPublic, "render()", .struct, at: "render", in: source),
            FixTarget(rule: .redundantPublic, name: "render()", kind: .functionFree, file: file, line: 9, column: 1),
        ])

        XCTAssertEqual(plan.skipped.map(\.reason), Array(repeating: .locationMismatch, count: 4))
        XCTAssertTrue(plan.changes.isEmpty)
    }

    func testDirtyFileAndMissingRepositoryAreRefused() throws {
        let source = "public func render() {}\n"
        try write(source)
        try commitAll()
        let renderTarget = target(.redundantPublic, "render()", .functionFree, at: "render", in: source)

        XCTAssertEqual(try FixPlanner(workingTree: GitWorkingTree.state(at: directory), indexDates: nil) { _ in false }.plan([renderTarget]).applied, [renderTarget])

        try write(source + "// changed\n")
        let dirty = try FixPlanner(workingTree: GitWorkingTree.state(at: directory), indexDates: nil) { _ in false }
        XCTAssertEqual(dirty.plan([renderTarget]).skipped.map(\.reason), [.uncommittedChanges])

        let noRepository = FixPlanner(workingTree: .notARepository, indexDates: nil) { _ in false }
        XCTAssertEqual(noRepository.plan([renderTarget]).skipped.map(\.reason), [.notInGitRepository])
    }

    func testFilesGitCannotRestoreAreRefused() throws {
        let source = "public func render() {}\n"
        try write(source)
        try commitAll()

        let outside = try makeTemporaryDirectory("outside")
        let outsideFile = outside.appending("Outside.swift")
        try Data(source.utf8).write(to: URL(fileURLWithPath: outsideFile.string))
        let link = directory.appending("Link.swift")
        try FileManager.default.createSymbolicLink(atPath: link.string, withDestinationPath: outsideFile.string)

        let origin = try makeTemporaryDirectory("submodule")
        try Data(source.utf8).write(to: URL(fileURLWithPath: origin.appending("Sub.swift").string))
        try git(in: origin, "init", "-q")
        try git(in: origin, "add", "Sub.swift")
        try git(in: origin, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "init")
        try git("-c", "protocol.file.allow=always", "submodule", "add", "-q", origin.string, "Sub")
        try commitAll()

        let planner = try FixPlanner(workingTree: GitWorkingTree.state(at: directory), indexDates: nil) { _ in false }
        let targets = [link, outsideFile, directory.appending("Sub/Sub.swift")].map { path in
            FixTarget(rule: .redundantPublic, name: "render()", kind: .functionFree, file: path, line: 1, column: 13)
        }
        let reasons = planner.plan(targets).skipped.reduce(into: [String: SkipReason]()) { $0[$1.target.file.lastComponent?.string ?? ""] = $1.reason }

        XCTAssertEqual(reasons, ["Link.swift": .symbolicLink, "Outside.swift": .outsideRepository, "Sub.swift": .nestedRepository])
        XCTAssertEqual(try String(contentsOfFile: outsideFile.string, encoding: .utf8), source)
    }

    func testGitWorkingTreeReportsModifiedAndUntrackedFiles() throws {
        try write("let x = 1\n")
        try git("init", "-q")
        try git("add", "File.swift")
        try git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "init")
        XCTAssertEqual(try uncommitted(), [])

        try write("let x = 2\n")
        let untracked = directory.appending("New.swift")
        try "let y = 1\n".write(toFile: untracked.string, atomically: true, encoding: .utf8)
        XCTAssertEqual(try uncommitted(), [RealPath.resolve(file.string), RealPath.resolve(untracked.string)])

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-fix-nogit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        guard case .notARepository = try GitWorkingTree.state(at: FilePath(outside.path)) else {
            return XCTFail("a directory outside any repository is not a working tree")
        }
    }

    func testGeneratedIndexExcludedAndChangedFilesAreRefused() throws {
        let generated = "// Generated by SwiftGen, do not edit.\npublic func render() {}\n"
        XCTAssertEqual(try planned(generated, [target(.redundantPublic, "render()", .functionFree, at: "render", in: generated)]).skipped.map(\.reason), [.generatedFile])

        let source = "public func render() {}\n"
        try write(source)
        let renderTarget = target(.redundantPublic, "render()", .functionFree, at: "render", in: source)

        let excluded = FixPlanner(workingTree: .ignored, indexDates: nil) { _ in true }
        XCTAssertEqual(excluded.plan([renderTarget]).skipped.map(\.reason), [.indexExcluded])

        XCTAssertTrue(GeneratedFile.isGenerated(path: "/p/.build/debug/Foo.swift"))
        XCTAssertTrue(GeneratedFile.isGenerated(path: "/p/GeneratedAssetSymbols.swift"))
        XCTAssertFalse(GeneratedFile.isGenerated(path: "/p/Sources/Foo.swift"))
    }

    func testFileModifiedAfterItsIndexUnitIsRefused() throws {
        let source = "public func render() {}\n"
        try write(source)
        let renderTarget = target(.redundantPublic, "render()", .functionFree, at: "render", in: source)
        let later = Date(timeIntervalSinceNow: 60)

        func reasons(_ dates: IndexDates) -> [SkipReason] {
            FixPlanner(workingTree: .ignored, indexDates: dates) { _ in false }.plan([renderTarget]).skipped.map(\.reason)
        }

        // The scan started after the edit, but the index store was written before it, e.g. with --skip-build.
        XCTAssertEqual(reasons(IndexDates(scanStartedAt: later, unitDates: [file: Date(timeIntervalSinceNow: -3600)])), [.changedSinceIndexing])
        XCTAssertEqual(reasons(IndexDates(scanStartedAt: later, unitDates: [:])), [.changedSinceIndexing])
        XCTAssertEqual(reasons(IndexDates(scanStartedAt: Date(timeIntervalSinceNow: -3600), unitDates: [file: later])), [.changedSinceIndexing])
        XCTAssertEqual(reasons(IndexDates(scanStartedAt: later, unitDates: [file: later])), [])
    }

    func testLocationOverrideIsSkipped() throws {
        let source = "public func render() {}\n"
        let overridden = FixTarget(rule: .redundantPublic, name: "render()", kind: .functionFree, file: file, line: 1, column: 13, hasLocationOverride: true)

        XCTAssertEqual(try planned(source, [overridden]).skipped.map(\.reason), [.locationOverride])
    }

    // MARK: - Private

    private var file: FilePath {
        directory.appending("File.swift")
    }

    private func makePlanner() -> FixPlanner {
        FixPlanner(workingTree: .ignored, indexDates: nil) { _ in false }
    }

    private func write(_ source: String) throws {
        try Data(source.utf8).write(to: URL(fileURLWithPath: file.string))
    }

    private func planned(_ source: String, _ targets: [FixTarget]) throws -> FixPlan {
        try write(source)
        return makePlanner().plan(targets)
    }

    private func apply(_ plan: FixPlan) throws -> String {
        try FixWriter.apply(plan)
        return try XCTUnwrap(String(validating: Data(contentsOf: URL(fileURLWithPath: file.string)), as: UTF8.self))
    }

    private func fix(_ source: String, _ targets: [FixTarget], file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let plan = try planned(source, targets)
        XCTAssertEqual(plan.skipped.map { "\($0.target.name): \($0.reason)" }, [], file: file, line: line)
        return try apply(plan)
    }

    private func target(
        _ rule: FixRule,
        _ name: String,
        _ kind: Declaration.Kind,
        at marker: String,
        in source: String,
        accessibility: Accessibility? = nil,
        occurrence: Int = 1
    ) -> FixTarget {
        var searchStart = source.startIndex
        var found: Range<String.Index>?
        for _ in 0 ..< occurrence {
            found = source.range(of: marker, range: searchStart ..< source.endIndex)
            searchStart = found?.upperBound ?? source.endIndex
        }
        guard let range = found else {
            XCTFail("'\(marker)' is not in the source")
            return FixTarget(rule: rule, name: name, kind: kind, file: file, line: 0, column: 0)
        }

        let prefix = source[..<range.lowerBound]
        let line = prefix.count(where: { $0 == "\n" }) + 1
        let lineStart = prefix.lastIndex(of: "\n").map { source.index(after: $0) } ?? source.startIndex
        let column = source[lineStart ..< range.lowerBound].utf8.count + 1
        return FixTarget(rule: rule, name: name, kind: kind, file: file, line: line, column: column, accessibility: accessibility)
    }

    private func makeTemporaryDirectory(_ name: String) throws -> FilePath {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-fix-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return FilePath(url.path)
    }

    private func commitAll() throws {
        if !FileManager.default.fileExists(atPath: directory.appending(".git").string) {
            try git("init", "-q")
        }
        try git("add", "-A")
        try git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "commit")
    }

    private func git(_ arguments: String...) throws {
        try git(in: directory, arguments)
    }

    private func git(in directory: FilePath, _ arguments: String...) throws {
        try git(in: directory, arguments)
    }

    private func git(in directory: FilePath, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", directory.string] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "git \(arguments.joined(separator: " "))")
    }

    private func uncommitted() throws -> Set<String> {
        guard case let .repository(_, paths) = try GitWorkingTree.state(at: directory) else {
            XCTFail("the directory is a working tree")
            return []
        }

        return paths
    }
}
