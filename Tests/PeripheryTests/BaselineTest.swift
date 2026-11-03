import Configuration
import Foundation
@testable import Indexer
import Logger
@testable import PeripheryKit
@testable import SourceGraph
import SystemPackage
import XCTest

/// The ids of unused imports, empty extensions and String Catalog keys are stored in baselines, so they must not
/// change when a line shifts or when the project is checked out elsewhere.
final class BaselineTest: XCTestCase {
    private let quietLogger = Logger(quiet: true, verbose: false, colorMode: .never)
    private let rootA = "/Users/dev/checkout-a"
    private let rootB = "/Users/dev/checkout-b"

    private let importId = "import-Util-Sources/Lib/Lib.swift"
    private let extensionId = "empty-extension-Used-Sources/Lib/Lib.swift"

    // MARK: - Fixtures

    private func configuration(root: String) -> Configuration {
        let configuration = Configuration()
        configuration.projectRoot = FilePath(root)
        return configuration
    }

    private func importStatement(_ module: String, in file: SourceFile, line: Int) -> ImportStatement {
        ImportStatement(
            module: module,
            isTestable: false,
            isExported: false,
            isConditional: false,
            location: Location(file: file, line: line, column: 1),
            endLocation: Location(file: file, line: line, column: 8 + module.count),
            commentCommands: []
        )
    }

    /// The results of a scan of `Sources/Lib/Lib.swift`, whose unused `import Util` and empty `extension Used {}`
    /// sit at the given lines.
    private func scanLib(root: String, importLines: [Int] = [2], extensionLines: [Int] = [13], extraImports: [String] = []) -> [ScanResult] {
        let graph = SourceGraph(configuration: configuration(root: root), logger: quietLogger)
        let file = SourceFile(path: FilePath(root).appending("Sources/Lib/Lib.swift"), modules: ["Lib"])

        for line in importLines {
            graph.markUnusedModuleImport(importStatement("Util", in: file, line: line))
        }

        for module in extraImports {
            graph.markUnusedModuleImport(importStatement(module, in: file, line: 1))
        }

        for line in extensionLines {
            graph.markEmptyExtension(extendedTypeName: "Used", location: Location(file: file, line: line, column: 11))
        }

        return graph.unusedModuleImports.map { ScanResult(declaration: $0, annotation: .unused) }
            + graph.emptyExtensions.map { ScanResult(declaration: $0, annotation: .emptyExtension) }
    }

    private func usrs(of results: [ScanResult]) -> [String] {
        results.flatMap(\.usrs).sorted()
    }

    /// What `--write-baseline` followed by `--baseline` does to the file.
    private func writeBaseline(from results: [ScanResult]) throws -> Baseline {
        let data = try JSONEncoder().encode(Baseline.v1(usrs: usrs(of: results)))
        return try JSONDecoder().decode(Baseline.self, from: data)
    }

    private func filter(_ results: [ScanResult], with baseline: Baseline, root: String, logger: Logger? = nil) throws -> [ScanResult] {
        try OutputDeclarationFilter(configuration: configuration(root: root), logger: logger ?? quietLogger)
            .filter(results, with: baseline)
    }

    /// The String Catalog keys `goodbye` and `hello` of `Sources/Kit/Strings.xcstrings` under a project root, as
    /// reported by a scan in which only `goodbye` is unused.
    private func scanCatalog(root: FilePath, relativePath: String = "Sources/Kit/Strings.xcstrings") throws -> [ScanResult] {
        let catalog = root.appending(relativePath)
        try FileManager.default.createDirectory(atPath: catalog.removingLastComponent().string, withIntermediateDirectories: true)
        try Data("""
        {
          "sourceLanguage": "en",
          "version": "1.0",
          "strings": { "hello": {}, "goodbye": {}, "a:b": {} }
        }
        """.utf8).write(to: catalog.url)

        let configuration = configuration(root: root.string)
        let graph = SourceGraph(configuration: configuration, logger: quietLogger)
        try XCStringsIndexer(
            files: [catalog],
            graph: SourceGraphMutex(graph: graph),
            logger: quietLogger.contextualized(with: "test"),
            configuration: configuration
        ).perform()

        return graph.allDeclarations
            .filter { $0.kind == .localizedString && $0.name != "hello" }
            .map { ScanResult(declaration: $0, annotation: .unused) }
    }

    private func makeCheckoutDirectory(_ name: String) throws -> FilePath {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BaselineTest-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return FilePath(directory.path).appending(name)
    }

    private func captureStandardError(_ body: () throws -> Void) throws -> String {
        try capture(STDERR_FILENO, body)
    }

    private func capture(_ descriptor: Int32, _ body: () throws -> Void) throws -> String {
        let pipe = Pipe()
        let original = dup(descriptor)
        fflush(stderr)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, descriptor)

        defer {
            dup2(original, descriptor)
            close(original)
        }

        try body()
        fflush(stderr)
        fflush(stdout)
        dup2(original, descriptor)
        pipe.fileHandleForWriting.closeFile()
        return try XCTUnwrap(String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8))
    }

    // MARK: - Ids

    func testUnusedImportAndEmptyExtensionIds_holdNoLineOrColumn() {
        XCTAssertEqual(usrs(of: scanLib(root: rootA)), [extensionId, importId])
    }

    func testEmptyExtensionsOfOneTypeInAFile_haveDistinctIdsThatDoNotDependOnTheLines() {
        let ids = usrs(of: scanLib(root: rootA, importLines: [], extensionLines: [5, 20, 30]))
        XCTAssertEqual(ids, [extensionId, "\(extensionId)#2", "\(extensionId)#3"])

        XCTAssertEqual(usrs(of: scanLib(root: rootA, importLines: [], extensionLines: [8, 23, 33])), ids)
        XCTAssertEqual(
            Set(usrs(of: scanLib(root: rootA, importLines: [], extensionLines: [5, 20, 30, 40]))).intersection(ids).count,
            3,
            "An extension added after the others must not rename them"
        )
    }

    func testImportsOfOneModuleInAFile_areAllReported() {
        let results = scanLib(root: rootA, importLines: [2, 3], extensionLines: [])

        XCTAssertEqual(usrs(of: results), [importId, "\(importId)#2"])
    }

    func testImportMarkedTwiceAtOneLocation_isReportedOnce() {
        let results = scanLib(root: rootA, importLines: [2, 2], extensionLines: [13, 13])

        XCTAssertEqual(usrs(of: results), [extensionId, importId])
    }

    func testSyntheticIds_containNoAbsolutePath() throws {
        let root = try makeCheckoutDirectory("checkout")
        let results = try scanLib(root: rootA) + scanCatalog(root: root)

        XCTAssertFalse(results.isEmpty)

        for usr in usrs(of: results) {
            XCTAssertFalse(usr.contains(rootA), usr)
            XCTAssertFalse(usr.contains(root.string), usr)
            XCTAssertFalse(usr.contains(":/") || usr.contains("-/"), usr)
        }
    }

    // MARK: - Baseline

    func testUnusedImportAndEmptyExtension_stayFilteredWhenLinesShift() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA, importLines: [2], extensionLines: [13]))
        let shifted = scanLib(root: rootA, importLines: [3], extensionLines: [14])

        XCTAssertEqual(try filter(shifted, with: baseline, root: rootA).count, 0)
    }

    func testUnusedImportAndEmptyExtension_stayFilteredInAnotherCheckout() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA))

        XCTAssertEqual(try filter(scanLib(root: rootB, importLines: [5], extensionLines: [20]), with: baseline, root: rootB).count, 0)
    }

    func testBaselineStillReportsANewUnusedImport() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA))
        let results = try filter(scanLib(root: rootA, extraImports: ["Other"]), with: baseline, root: rootA)

        XCTAssertEqual(usrs(of: results), ["import-Other-Sources/Lib/Lib.swift"])
    }

    func testBaselineStillReportsAnEmptyExtensionAddedAfterTheBaselinedOne() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA, extensionLines: [13]))
        let results = try filter(scanLib(root: rootA, importLines: [], extensionLines: [13, 30]), with: baseline, root: rootA)

        XCTAssertEqual(usrs(of: results), ["\(extensionId)#2"])
    }

    func testLocalizedString_isFilteredUnderAnotherProjectRoot() throws {
        let checkoutA = try makeCheckoutDirectory("checkout-a")
        let checkoutB = try makeCheckoutDirectory("checkout-b")
        let baselined = try scanCatalog(root: checkoutA)
        let baseline = try writeBaseline(from: baselined)

        XCTAssertEqual(baselined.count, 2)
        XCTAssertEqual(try filter(scanCatalog(root: checkoutB), with: baseline, root: checkoutB.string).count, 0)
    }

    func testLocalizedStringOfAnotherCatalog_isNotFilteredByTheBaselineOfAnotherCatalog() throws {
        let checkoutA = try makeCheckoutDirectory("checkout-a")
        let checkoutB = try makeCheckoutDirectory("checkout-b")
        let baseline = try writeBaseline(from: scanCatalog(root: checkoutA))
        let otherCatalog = try scanCatalog(root: checkoutB, relativePath: "Sources/Other/Strings.xcstrings")

        XCTAssertEqual(try filter(otherCatalog, with: baseline, root: checkoutB.string).count, 2)
    }

    // MARK: - Baselines written by earlier versions

    func testLegacyPositionalIds_stillFilterUnusedImportAndEmptyExtension() throws {
        let baseline = Baseline.v1(usrs: ["import-Util-Sources/Lib/Lib.swift:2:1", "empty-extension-Used-Sources/Lib/Lib.swift:13:11"])
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)
        var remaining: [ScanResult] = []

        let output = try captureStandardError {
            remaining = try filter(scanLib(root: rootA), with: baseline, root: rootA, logger: logger)
        }

        XCTAssertEqual(remaining.count, 0)
        XCTAssertTrue(output.contains("--write-baseline"), output)
    }

    func testLegacyPositionalIds_followTheLineOfTheResult() throws {
        let baseline = Baseline.v1(usrs: ["import-Util-Sources/Lib/Lib.swift:2:1", "empty-extension-Used-Sources/Lib/Lib.swift:13:11"])
        let moved = try filter(scanLib(root: rootA, importLines: [3], extensionLines: [14]), with: baseline, root: rootA)

        XCTAssertEqual(usrs(of: moved), [extensionId, importId], "A legacy id is positional, so a moved result is a new one")
    }

    func testLegacyAbsoluteCatalogId_stillFiltersInTheSameCheckout() throws {
        let checkout = try makeCheckoutDirectory("checkout")
        let results = try scanCatalog(root: checkout)
        let baseline = Baseline.v1(usrs: results.map { "xcstrings:\(checkout.appending("Sources/Kit/Strings.xcstrings").string):\($0.declaration.name)" })

        XCTAssertEqual(try filter(results, with: baseline, root: checkout.string).count, 0)
    }

    func testLegacyAbsoluteCatalogId_matchesTheCatalogOfAnotherCheckoutAndWarns() throws {
        let checkout = try makeCheckoutDirectory("checkout-b")
        let baseline = Baseline.v1(usrs: [
            "xcstrings:/Users/dev/checkout-a/Sources/Kit/Strings.xcstrings:goodbye",
            "xcstrings:/Users/dev/checkout-a/Sources/Kit/Strings.xcstrings:a:b",
        ])
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)
        let results = try scanCatalog(root: checkout)
        var remaining: [ScanResult] = []

        let output = try captureStandardError {
            remaining = try filter(results, with: baseline, root: checkout.string, logger: logger)
        }

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(remaining.count, 0)
        XCTAssertTrue(output.contains("--write-baseline"), output)
    }

    func testLegacyAbsoluteCatalogId_doesNotMatchAnotherCatalogOrKey() throws {
        let checkout = try makeCheckoutDirectory("checkout-b")
        let baseline = Baseline.v1(usrs: [
            "xcstrings:/Users/dev/checkout-a/Sources/Kit/Strings.xcstrings:goodbye",
        ])
        let otherCatalog = try scanCatalog(root: checkout, relativePath: "Sources/Other/Strings.xcstrings")
        let sameCatalog = try scanCatalog(root: checkout)

        XCTAssertEqual(try filter(otherCatalog, with: baseline, root: checkout.string).count, 2)
        XCTAssertEqual(usrs(of: try filter(sameCatalog, with: baseline, root: checkout.string)), ["xcstrings:Sources/Kit/Strings.xcstrings:a:b"])
    }

    func testBaselineWithCurrentIds_doesNotWarnAboutLegacyIds() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA))
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)

        let output = try captureStandardError {
            _ = try filter(scanLib(root: rootA), with: baseline, root: rootA, logger: logger)
        }

        XCTAssertFalse(output.contains("--write-baseline"), output)
    }

    // MARK: - Stale entries

    func testStaleEntries_areCountedAndLogged() throws {
        let baseline = Baseline.v1(usrs: [importId, "s:3Lib10unusedFuncyyF", "s:3Lib7movedFuncyyF"])
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)
        let filter = OutputDeclarationFilter(configuration: configuration(root: rootA), logger: logger)
        var remaining: [ScanResult] = []

        let output = try capture(STDOUT_FILENO) {
            remaining = try filter.filter(scanLib(root: rootA, extensionLines: []), with: baseline)
        }

        XCTAssertEqual(remaining.count, 0)
        XCTAssertEqual(filter.staleBaselineEntries, ["s:3Lib10unusedFuncyyF", "s:3Lib7movedFuncyyF"])
        XCTAssertTrue(output.contains("2 baseline entries no longer match any result"), output)
        XCTAssertFalse(output.contains("s:3Lib10unusedFuncyyF"), "The entries are only listed with --verbose")
    }

    func testStaleEntries_areListedWithVerbose() throws {
        let baseline = Baseline.v1(usrs: [importId, "s:3Lib10unusedFuncyyF"])
        let logger = Logger(quiet: false, verbose: true, colorMode: .never)

        let output = try capture(STDOUT_FILENO) {
            _ = try filter(scanLib(root: rootA, extensionLines: []), with: baseline, root: rootA, logger: logger)
        }

        XCTAssertTrue(output.contains("1 baseline entry no longer matches any result"), output)
        XCTAssertTrue(output.contains("s:3Lib10unusedFuncyyF"), output)
    }

    func testNoStaleEntries_logsNothing() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA))
        let logger = Logger(quiet: false, verbose: true, colorMode: .never)
        let filter = OutputDeclarationFilter(configuration: configuration(root: rootA), logger: logger)

        let output = try capture(STDOUT_FILENO) {
            _ = try filter.filter(scanLib(root: rootA), with: baseline)
        }

        XCTAssertTrue(filter.staleBaselineEntries.isEmpty)
        XCTAssertFalse(output.contains("no longer match"), output)
    }

    func testEntryOfAnExcludedFile_isNotStale() throws {
        let baseline = try writeBaseline(from: scanLib(root: rootA))
        let configuration = configuration(root: rootA)
        configuration.reportExclude = [.pattern("**/Lib.swift")]
        configuration.buildFilenameMatchers()
        let filter = OutputDeclarationFilter(configuration: configuration, logger: quietLogger)

        let remaining = try filter.filter(scanLib(root: rootA), with: baseline)

        XCTAssertTrue(remaining.isEmpty)
        XCTAssertTrue(filter.staleBaselineEntries.isEmpty)
    }

    func testStaleLegacyEntries_areNotCountedWhenTheyMatch() throws {
        let baseline = Baseline.v1(usrs: ["import-Util-Sources/Lib/Lib.swift:2:1", "empty-extension-Used-Sources/Lib/Lib.swift:13:11"])
        let filter = OutputDeclarationFilter(configuration: configuration(root: rootA), logger: quietLogger)

        _ = try filter.filter(scanLib(root: rootA), with: baseline)

        XCTAssertTrue(filter.staleBaselineEntries.isEmpty)
    }
}
