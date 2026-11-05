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

        return try JobPool(jobs: Array(indexStorePaths))
            .flatMap { indexStorePath in
                logger.debug("Reading \(indexStorePath)")
                let indexStore = try IndexStore(path: indexStorePath.string)

                let unitsDirectory = indexStorePath.appending("v5/units")

                return indexStore.units.filter { !$0.isSystem }.compactMap { unit -> (FilePath, IndexStore, UnitReader, String, Date?)? in
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

                        return (file, indexStore, unit, unit.moduleName, Self.modificationDate(of: unitsDirectory.appending(unit.name)))
                    }

                    return nil
                }
            }
            .reduce(into: [FilePath: [(IndexStore, UnitReader, String, Date?)]]()) { result, tuple in
                let (file, indexStore, unit, module, date) = tuple
                result[file, default: []].append((indexStore, unit, module, date))
            }
            .reduce(into: [SourceFile: [IndexUnit]]()) { result, pair in
                let (file, allTuples) = pair
                let tuples = Self.currentUnits(
                    allTuples,
                    sourceModificationDate: Self.modificationDate(of: file),
                    module: \.2,
                    modificationDate: \.3
                )
                let modules = tuples.compactMapSet { $0.2 }
                let sourceFile = SourceFile(path: file, modules: modules)
                let units = tuples.map { IndexUnit(store: $0.0, unit: $0.1) }
                result[sourceFile] = units
            }
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
