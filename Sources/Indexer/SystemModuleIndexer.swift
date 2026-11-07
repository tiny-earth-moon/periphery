import IndexStore
import Logger
import Shared
import SourceGraph
import SystemPackage

/// Reads the system units of the index stores (SDK frameworks indexed alongside the project) so that unused imports
/// of system modules can be identified: which system modules are present, the modules each of them depends on, and
/// which system module declares each external declaration referenced by the project.
final class SystemModuleIndexer {
    private struct RecordKey: Hashable {
        let storePath: FilePath
        let name: String
    }

    private struct SystemRecord {
        let store: IndexStore
        let name: String
        let module: String
    }

    private let indexStorePaths: Set<FilePath>
    private let graph: SourceGraphMutex
    private let logger: ContextualLogger

    init(indexStorePaths: Set<FilePath>, graph: SourceGraphMutex, logger: ContextualLogger) {
        self.indexStorePaths = indexStorePaths
        self.graph = graph
        self.logger = logger.contextualized(with: "system-modules")
    }

    func perform() throws {
        let externalUsrs = graph.withLock { graph in
            graph.allReferences
                .filter { $0.declarationKind != .module && graph.declaration(withUsr: $0.usr) == nil }
                .mapSet(\.usr)
        }

        var modules: Set<String> = []
        var targets: Set<String> = []
        var exports: [String: Set<String>] = [:]
        var records: [RecordKey: SystemRecord] = [:]

        for storePath in indexStorePaths {
            let store = try IndexStore(path: storePath.string)

            for unit in store.units where unit.isSystem {
                let module = Self.topLevelModule(unit.moduleName)
                guard !module.isEmpty else { continue }

                modules.insert(module)
                targets.insert(unit.target)
                unit.forEach(dependency: { dependency in
                    let dependencyModule = Self.topLevelModule(dependency.moduleName)

                    if dependency.kind == .unit {
                        if !dependencyModule.isEmpty {
                            exports[module, default: []].insert(dependencyModule)
                        }
                    } else if dependency.kind == .record {
                        let recordModule = dependencyModule.isEmpty ? module : dependencyModule
                        records[RecordKey(storePath: storePath, name: dependency.name)] = SystemRecord(
                            store: store,
                            name: dependency.name,
                            module: recordModule
                        )
                    }
                })
            }
        }

        logger.debug("\(modules.count) system modules, \(records.count) system records, targets: \(targets.sorted())")

        let declaringRoles: SymbolRoles = [.definition, .declaration]
        let modulesByUsr = try JobPool(jobs: Array(records.values)).flatMap { record -> [(String, String)] in
            var declared: [(String, String)] = []
            try RecordReader(indexStore: record.store, recordName: record.name).forEach(occurrence: { occurrence in
                guard !occurrence.roles.isDisjoint(with: declaringRoles) else { return }

                let usr = occurrence.symbol.usr
                if externalUsrs.contains(usr) {
                    declared.append((usr, record.module))
                }
            })
            return declared
        }
        .reduce(into: [String: Set<String>]()) { result, pair in
            result[pair.0, default: []].insert(pair.1)
        }

        graph.withLock { graph in
            graph.addSystemModules(modules, exports: exports, modulesByUsr: modulesByUsr, targets: targets)
        }
    }

    /// `Foundation.NSString` (a Clang submodule) is imported as `Foundation`.
    private static func topLevelModule(_ name: String) -> String {
        String(name.prefix { $0 != "." })
    }
}
