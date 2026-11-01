import Configuration
import Foundation
import Logger
import Shared
import SystemPackage

/// Compares the source files of the scanned targets with the files the index store(s) provided units for.
struct IndexCoverage {
    struct Gap: Equatable {
        let target: String
        let files: [FilePath]
    }

    let plan: IndexPlan
    let logger: ContextualLogger
    let configuration: Configuration

    func verify() throws {
        let storeList = plan.indexStorePaths.map(\.string).sorted().joined(separator: ", ")

        for gap in try gaps() {
            logger.warn("\(gap.files.count) source file(s) in target \(gap.target) have no index data; results for them are not reliable (index store: \(storeList))")

            for file in gap.files {
                logger.debug("No index data: \(file.string)")
            }
        }
    }

    /// Targets with only some of their files indexed. Throws when none of the expected files is indexed.
    func gaps() throws -> [Gap] {
        let indexed = Set(plan.sourceFiles.keys.map { $0.path.lexicallyNormalized() })
        let expected = plan.expectedSourceFiles
            .mapValues { $0.filter { !configuration.isIndexExcluded($0) } }
            .filter { !$0.value.isEmpty }
        let allExpected = Set(expected.values.joined())

        if !allExpected.isEmpty, indexed.isDisjoint(with: allExpected) {
            throw PeripheryError.noIndexedSourceFiles(
                fileCount: allExpected.count,
                indexStorePaths: plan.indexStorePaths.map(\.string).sorted()
            )
        }

        // A target without any indexed file was most likely not built (e.g. outside the scanned scheme).
        return expected.sorted { $0.key < $1.key }.compactMap { target, files in
            let missing = files.subtracting(indexed)
            guard !missing.isEmpty, missing.count < files.count else { return nil }

            return Gap(target: target, files: missing.sorted { $0.string < $1.string })
        }
    }
}
