import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

/// `--changed-since` and `--changed-lines` against a real git repository created in a temporary directory.
final class ChangedSinceFilterTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)
    private lazy var shell = ShellImpl(logger: logger)
    private var root: URL!

    private static let tenLines = (1 ... 10).map { "line \($0)" }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-changed-since-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixtures

    @discardableResult
    private func git(_ args: String..., in directory: URL? = nil) throws -> String {
        try shell.exec(["git", "-C", (directory ?? root).path] + args)
    }

    private func write(_ lines: [String], to name: String) throws {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func commit(_ message: String) throws {
        try git("add", "-A")
        try git("commit", "-q", "-m", message)
    }

    /// Two commits: the first adds `Sources/A.swift` and `Sources/B.swift`, the second changes line 5 of `A.swift`.
    private func makeRepository() throws {
        try git("init", "-q")
        try git("config", "user.name", "Test")
        try git("config", "user.email", "test@example.com")
        try git("config", "commit.gpgsign", "false")
        try write(Self.tenLines, to: "Sources/A.swift")
        try write(Self.tenLines, to: "Sources/B.swift")
        try commit("first")
        var changed = Self.tenLines
        changed[4] = "changed 5"
        try write(changed, to: "Sources/A.swift")
        try commit("second")
    }

    private func result(_ name: String, in file: String, line: Int) -> ScanResult {
        let path = FilePath(root.path).appending(file)
        let location = Location(file: SourceFile(path: path, modules: ["Lib"]), line: line, column: 1)
        let declaration = Declaration(name: name, kind: .extension, usrs: ["usr-\(name)"], location: location)
        return ScanResult(declaration: declaration, annotation: .emptyExtension)
    }

    private func names(since ref: String?, lines: Bool = false, _ results: [ScanResult]) throws -> [String] {
        let configuration = Configuration()
        configuration.projectRoot = FilePath(root.path)
        configuration.changedSince = ref
        configuration.changedLines = lines

        return try ChangedSinceFilter(configuration: configuration, shell: shell, logger: logger)
            .filter(results)
            .map(\.declaration.name)
            .sorted()
    }

    private var sample: [ScanResult] {
        [
            result("a2", in: "Sources/A.swift", line: 2),
            result("a5", in: "Sources/A.swift", line: 5),
            result("b3", in: "Sources/B.swift", line: 3),
        ]
    }

    // MARK: - Tests

    func testWithoutRefKeepsEveryResult() throws {
        try makeRepository()
        XCTAssertEqual(try names(since: nil, sample), ["a2", "a5", "b3"])
    }

    func testKeepsOnlyResultsInFilesChangedSinceTheRef() throws {
        try makeRepository()
        XCTAssertEqual(try names(since: "HEAD~1", sample), ["a2", "a5"])
    }

    func testChangedLinesKeepsOnlyResultsInsideChangedHunks() throws {
        try makeRepository()
        XCTAssertEqual(try names(since: "HEAD~1", lines: true, sample), ["a5"])
    }

    func testChangedLinesCountsUncommittedHunks() throws {
        try makeRepository()
        var edited = Self.tenLines
        edited[4] = "changed 5"
        edited[1] = "edited 2"
        try write(edited, to: "Sources/A.swift")
        XCTAssertEqual(try names(since: "HEAD~1", lines: true, sample), ["a2", "a5"])
    }

    func testUncommittedChangesInOtherwiseUnchangedFileAreKept() throws {
        try makeRepository()
        var edited = Self.tenLines
        edited[2] = "edited 3"
        try write(edited, to: "Sources/B.swift")
        XCTAssertEqual(try names(since: "HEAD", sample), ["b3"])
        XCTAssertEqual(try names(since: "HEAD", lines: true, sample), ["b3"])
    }

    func testRenamedFileIsMatchedByItsNewPath() throws {
        try makeRepository()
        try git("mv", "Sources/B.swift", "Sources/C.swift")
        try commit("rename")

        XCTAssertEqual(try names(since: "HEAD~1", [result("b3", in: "Sources/B.swift", line: 3), result("c3", in: "Sources/C.swift", line: 3)]), ["c3"])
        XCTAssertEqual(try names(since: "HEAD~1", lines: true, [result("c3", in: "Sources/C.swift", line: 3)]), [])
    }

    func testUntrackedFileResultsAreKeptOnEveryLine() throws {
        try makeRepository()
        try write(Self.tenLines, to: "Sources/New.swift")
        let results = [result("n7", in: "Sources/New.swift", line: 7), result("b3", in: "Sources/B.swift", line: 3)]

        XCTAssertEqual(try names(since: "HEAD", results), ["n7"])
        XCTAssertEqual(try names(since: "HEAD", lines: true, results), ["n7"])
    }

    func testGitIgnoredFileIsNotChanged() throws {
        try makeRepository()
        try write(["Ignored.swift"], to: ".gitignore")
        try commit("ignore")
        try write(Self.tenLines, to: "Ignored.swift")
        XCTAssertEqual(try names(since: "HEAD", [result("i1", in: "Ignored.swift", line: 1)]), [])
    }

    func testProjectRootInASubdirectoryResolvesPathsAgainstTheTopLevel() throws {
        try makeRepository()
        try write(Self.tenLines, to: "pkg/Sources/P.swift")
        try commit("package")
        try write(Self.tenLines + ["line 11"], to: "pkg/Sources/P.swift")

        let configuration = Configuration()
        configuration.projectRoot = FilePath(root.appendingPathComponent("pkg").path)
        configuration.changedSince = "HEAD~1"
        configuration.changedLines = true

        let results = [result("p11", in: "pkg/Sources/P.swift", line: 11), result("a5", in: "Sources/A.swift", line: 5)]
        let kept = try ChangedSinceFilter(configuration: configuration, shell: shell, logger: logger).filter(results)
        XCTAssertEqual(kept.map(\.declaration.name), ["p11"])
    }

    func testLocationOverrideFileIsMatchedInsteadOfTheDeclarationFile() throws {
        try makeRepository()
        let base = result("moved", in: "Sources/B.swift", line: 3)
        let overridePath = FilePath(root.path).appending("Sources/A.swift")
        base.declaration.commentCommands = [.override([.location(overridePath, 5, 1)])]

        XCTAssertEqual(try names(since: "HEAD~1", lines: true, [base]), ["moved"])
    }

    func testUnknownRefFailsNamingTheRef() throws {
        try makeRepository()

        XCTAssertThrowsError(try names(since: "no-such-ref", sample)) { error in
            guard case let PeripheryError.unknownGitRef(ref) = error else {
                return XCTFail("Expected an unknown ref error, received \(error)")
            }

            XCTAssertEqual(ref, "no-such-ref")
            XCTAssertTrue(error.localizedDescription.contains("no-such-ref"))
        }
    }

    func testRefThatLooksLikeAnOptionIsRefused() throws {
        try makeRepository()

        XCTAssertThrowsError(try names(since: "--output=x", sample)) { error in
            guard case PeripheryError.unknownGitRef = error else {
                return XCTFail("Expected an unknown ref error, received \(error)")
            }
        }
    }

    func testOutsideAGitWorkTreeFails() throws {
        XCTAssertThrowsError(try names(since: "HEAD", sample)) { error in
            guard case let PeripheryError.notInGitWorkTree(path) = error else {
                return XCTFail("Expected a work tree error, received \(error)")
            }

            XCTAssertEqual(path, root.path)
        }
    }

    func testHunkHeadersGiveNewSideRanges() {
        let patch = """
        diff --git Sources/A.swift Sources/A.swift
        --- Sources/A.swift
        +++ Sources/A.swift
        @@ -2 +2 @@ func f() {
        -x
        +y
        @@ -7,2 +7,0 @@
        -a
        -b
        @@ -9,0 +10,3 @@
        +a
        diff --git Sources/Gone.swift Sources/Gone.swift
        --- Sources/Gone.swift
        +++ /dev/null
        @@ -1,2 +0,0 @@
        """

        let parsed = ChangedSinceFilter.parseHunksForTesting(patch)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.file, "Sources/A.swift")
        XCTAssertEqual(parsed.first?.ranges, [2 ..< 3, 7 ..< 7, 10 ..< 13])
    }
}
