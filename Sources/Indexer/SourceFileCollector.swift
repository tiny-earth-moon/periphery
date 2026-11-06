import Configuration
import Foundation
import IndexStore
import Logger
import Shared
import SourceGraph
import SystemPackage

public struct SourceFileCollector {
    private let indexStorePaths: Set<FilePath>
    private let excludedTestTargets: Set<String>
    private let logger: ContextualLogger
    private let configuration: Configuration

    public init(
        indexStorePaths: Set<FilePath>,
        excludedTestTargets: Set<String>,
        logger: ContextualLogger,
        configuration: Configuration
    ) {
        self.indexStorePaths = indexStorePaths
        self.excludedTestTargets = excludedTestTargets
        self.logger = logger
        self.configuration = configuration
    }

    public func collect() throws -> [SourceFile: [IndexUnit]] {
        let excludedTargets = excludedTestTargets.union(configuration.excludeTargets)
        let currentFilePath = FilePath.current

        let collected = try JobPool(jobs: Array(indexStorePaths))
            .flatMap { indexStorePath in
                logger.debug("Reading \(indexStorePath)")
                let indexStore = try IndexStore(path: indexStorePath.string)

                let unitsDirectory = indexStorePath.appending("v5/units")

                return indexStore.units.filter { !$0.isSystem }.compactMap { unit -> (FilePath, FilePath, IndexStore, UnitReader, String, Date?)? in
                    let filePath = unit.mainFile

                    guard !filePath.isEmpty else {
                        return nil
                    }

                    let file = FilePath.makeAbsolute(filePath, relativeTo: currentFilePath)

                    if !isExcluded(file) {
                        guard file.exists else {
                            logger.debug("Source file does not exist: \(file.string)")
                            return nil
                        }

                        if excludedTargets.contains(unit.moduleName) {
                            return nil
                        }

                        return (file, indexStorePath, indexStore, unit, unit.moduleName, Self.modificationDate(of: unitsDirectory.appending(unit.name)))
                    }

                    return nil
                }
            }
            .reduce(into: [FilePath: [(FilePath, IndexStore, UnitReader, String, Date?)]]()) { result, tuple in
                let (file, indexStorePath, indexStore, unit, module, date) = tuple
                result[file, default: []].append((indexStorePath, indexStore, unit, module, date))
            }

        var sourceFiles: [SourceFile: [IndexUnit]] = [:]
        var outdatedFiles: [FilePath: Set<FilePath>] = [:]

        for (file, allTuples) in collected {
            let sourceModificationDate = Self.modificationDate(of: file)
            let tuples = Self.currentUnits(
                allTuples,
                sourceModificationDate: sourceModificationDate,
                module: \.3,
                modificationDate: \.4
            )
            let modules = tuples.compactMapSet { $0.3 }
            let sourceFile = SourceFile(path: file, modules: modules)
            sourceFiles[sourceFile] = tuples.map { IndexUnit(store: $0.1, unit: $0.2) }

            for tuple in Self.outdatedUnits(tuples, sourceModificationDate: sourceModificationDate, modificationDate: \.4) {
                outdatedFiles[tuple.0, default: []].insert(file)
            }
        }

        if let warning = try Self.outdatedIndexWarning(outdatedFiles, relativeTo: currentFilePath, strict: configuration.strictIndex) {
            logger.warn(warning)
        }

        return sourceFiles
    }

    /// A unit written before its source file was last modified describes an older version of the file, e.g. a unit
    /// left in the store by a build whose output paths have since changed (a renamed package, a restored CI cache).
    /// Such units are dropped when the same module has a unit written since, which describes the current file;
    /// otherwise they are kept, as they are the only index data available for the file.
    static func currentUnits<Unit>(
        _ units: [Unit],
        sourceModificationDate: Date?,
        module: (Unit) -> String,
        modificationDate: (Unit) -> Date?
    ) -> [Unit] {
        guard let sourceModificationDate else { return units }

        func isCurrent(_ unit: Unit) -> Bool {
            guard let date = modificationDate(unit) else { return false }

            return date >= sourceModificationDate
        }

        let modulesWithCurrentUnit = Set(units.filter(isCurrent).map(module))

        return units.filter { unit in
            guard modulesWithCurrentUnit.contains(module(unit)), modificationDate(unit) != nil else { return true }

            return isCurrent(unit)
        }
    }

    /// The units kept by `currentUnits` that were written before the source file was last modified: they are the
    /// only index data of their module for the file, yet describe an older version of it.
    static func outdatedUnits<Unit>(
        _ units: [Unit],
        sourceModificationDate: Date?,
        modificationDate: (Unit) -> Date?
    ) -> [Unit] {
        guard let sourceModificationDate else { return [] }

        return units.filter { unit in
            guard let date = modificationDate(unit) else { return false }

            return date < sourceModificationDate
        }
    }

    /// A single warning for the scan, naming each index store with its number of outdated files and a few of them.
    static func outdatedIndexWarning(_ outdatedFiles: [FilePath: Set<FilePath>], relativeTo base: FilePath, examples: Int = 3) -> String? {
        let stores = outdatedFiles
            .filter { !$0.value.isEmpty }
            .sorted { ($1.value.count, $0.key.string) < ($0.value.count, $1.key.string) }
        let count = stores.reduce(0) { $0 + $1.value.count }

        guard count > 0 else { return nil }

        func display(_ path: FilePath) -> String {
            path.starts(with: base) ? path.relativeTo(base).string : path.string
        }

        func list(_ files: Set<FilePath>) -> String {
            let names = files.map(display).sorted()
            let shown = names.prefix(examples).joined(separator: ", ")

            return names.count > examples ? "\(shown) and \(names.count - examples) more" : shown
        }

        let subject = count == 1 ? "1 source file is newer than its index data" : "\(count) source files are newer than their index data"
        let location = if stores.count == 1, let (store, files) = stores.first {
            " in \(display(store)): \(list(files))"
        } else {
            ": " + stores.map { "\($0.value.count) in \(display($0.key)) (\(list($0.value)))" }.joined(separator: ", ")
        }
        let pronoun = count == 1 ? "it" : "them"

        return "\(subject)\(location). Results in \(pronoun) may be at the wrong lines or missing: rebuild the project before scanning, or pass '--clean-build' to start from an empty index store."
    }

    /// The warning to print for the outdated files, if any; with `strict_index`, the scan fails instead.
    static func outdatedIndexWarning(_ outdatedFiles: [FilePath: Set<FilePath>], relativeTo base: FilePath, strict: Bool) throws -> String? {
        guard let warning = outdatedIndexWarning(outdatedFiles, relativeTo: base) else { return nil }

        if strict {
            throw PeripheryError.outdatedIndexData(message: warning + " Failing as '--strict-index' is set.")
        }

        return warning
    }

    // MARK: - Private

    private static func modificationDate(of path: FilePath) -> Date? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path.string)[.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    private func isExcluded(_ file: FilePath) -> Bool {
        configuration.isIndexExcluded(file)
    }
}
