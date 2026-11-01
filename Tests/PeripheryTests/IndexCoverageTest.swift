import Configuration
import Foundation
@testable import Indexer
import Logger
import Shared
import SourceGraph
import SystemPackage
import XCTest

final class IndexCoverageTest: XCTestCase {
    private let a = FilePath("/pkg/Sources/Lib/A.swift")
    private let b = FilePath("/pkg/Sources/Lib/B.swift")
    private let c = FilePath("/pkg/Sources/App/C.swift")

    private func coverage(indexed: [FilePath], expected: [String: Set<FilePath>], configuration: Configuration = Configuration()) -> IndexCoverage {
        let sourceFiles = Dictionary(uniqueKeysWithValues: indexed.map { (SourceFile(path: $0, modules: ["M"]), [IndexUnit]()) })
        let plan = IndexPlan(
            sourceFiles: sourceFiles,
            expectedSourceFiles: expected,
            indexStorePaths: [FilePath("/pkg/.build/index/store")]
        )
        return IndexCoverage(plan: plan, logger: Logger(quiet: true, verbose: false, colorMode: .never).contextualized(with: "test"), configuration: configuration)
    }

    func testFileMissingFromIndex_isReportedForItsTarget() throws {
        let gaps = try coverage(indexed: [a, c], expected: ["Lib": [a, b], "App": [c]]).gaps()

        XCTAssertEqual(gaps, [.init(target: "Lib", files: [b])])
    }

    func testFullyIndexedTargets_haveNoGap() throws {
        XCTAssertEqual(try coverage(indexed: [a, b, c], expected: ["Lib": [a, b], "App": [c]]).gaps(), [])
    }

    func testTargetWithoutAnyIndexedFile_isNotReportedWhenOthersAreIndexed() throws {
        XCTAssertEqual(try coverage(indexed: [a, b], expected: ["Lib": [a, b], "App": [c]]).gaps(), [])
    }

    func testNoIndexedFile_throwsExplicitError() {
        XCTAssertThrowsError(try coverage(indexed: [], expected: ["Lib": [a, b]]).gaps()) { error in
            guard case let PeripheryError.noIndexedSourceFiles(count, stores) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(count, 2)
            XCTAssertEqual(stores, ["/pkg/.build/index/store"])
        }
    }

    func testNoExpectedFiles_neverFails() throws {
        XCTAssertEqual(try coverage(indexed: [], expected: [:]).gaps(), [])
    }

    func testIndexExcludedFile_isNotExpected() throws {
        let configuration = Configuration()
        configuration.apply(\.$indexExclude, ["**/B.swift"])
        configuration.buildFilenameMatchers()
        XCTAssertEqual(try coverage(indexed: [a], expected: ["Lib": [a, b]], configuration: configuration).gaps(), [])
    }
}
