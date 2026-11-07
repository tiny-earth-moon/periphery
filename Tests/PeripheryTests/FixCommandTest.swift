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
        let renderTarget = target(.redundantPublic, "render()", .functionFree, at: "render", in: source)

        let dirty = FixPlanner(workingTree: .uncommitted([RealPath.resolve(file.string)]), indexedAt: nil) { _ in false }
        XCTAssertEqual(dirty.plan([renderTarget]).skipped.map(\.reason), [.uncommittedChanges])

        let noRepository = FixPlanner(workingTree: .notARepository, indexedAt: nil) { _ in false }
        XCTAssertEqual(noRepository.plan([renderTarget]).skipped.map(\.reason), [.notInGitRepository])

        let clean = FixPlanner(workingTree: .uncommitted([]), indexedAt: nil) { _ in false }
        XCTAssertEqual(clean.plan([renderTarget]).applied, [renderTarget])
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

        let excluded = FixPlanner(workingTree: .ignored, indexedAt: nil) { _ in true }
        XCTAssertEqual(excluded.plan([renderTarget]).skipped.map(\.reason), [.indexExcluded])

        let stale = FixPlanner(workingTree: .ignored, indexedAt: Date(timeIntervalSinceNow: -3600)) { _ in false }
        XCTAssertEqual(stale.plan([renderTarget]).skipped.map(\.reason), [.changedSinceIndexing])

        XCTAssertTrue(GeneratedFile.isGenerated(path: "/p/.build/debug/Foo.swift"))
        XCTAssertTrue(GeneratedFile.isGenerated(path: "/p/GeneratedAssetSymbols.swift"))
        XCTAssertFalse(GeneratedFile.isGenerated(path: "/p/Sources/Foo.swift"))
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
        FixPlanner(workingTree: .ignored, indexedAt: nil) { _ in false }
    }

    private func write(_ source: String) throws {
        try source.write(toFile: file.string, atomically: true, encoding: .utf8)
    }

    private func planned(_ source: String, _ targets: [FixTarget]) throws -> FixPlan {
        try write(source)
        return makePlanner().plan(targets)
    }

    private func apply(_ plan: FixPlan) throws -> String {
        try FixWriter.apply(plan)
        return try String(contentsOfFile: file.string, encoding: .utf8)
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

    private func git(_ arguments: String...) throws {
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
        guard case let .uncommitted(paths) = try GitWorkingTree.state(at: directory) else {
            XCTFail("the directory is a working tree")
            return []
        }

        return paths
    }
}
