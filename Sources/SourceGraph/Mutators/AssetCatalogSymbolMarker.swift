import Configuration
import Foundation
import Shared
import SystemPackage

/// Reports each asset whose generated symbols are all unused once, on its resource symbol
/// (e.g. `ColorResource.accent`), and keeps the other symbols of the asset (e.g. `Color.accent`) out of the
/// results. An asset with any used symbol is used.
final class AssetCatalogSymbolMarker: SourceGraphMutator {
    private struct AssetKey: Hashable, Comparable {
        let kind: AssetCatalogSymbolKind
        let symbolName: String

        static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.kind.rawValue, lhs.symbolName) < (rhs.kind.rawValue, rhs.symbolName)
        }
    }

    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        let kinds = AssetCatalogSymbolKind.detected(by: configuration)
        guard !kinds.isEmpty else { return }

        let roots = GeneratedAssetSymbols.rootDeclarations(in: graph, configuration: configuration)
        let rootsByFile = Dictionary(grouping: roots) { $0.location.file.path }
        let locator = AssetCatalogLocator(root: FilePath.current)

        for (file, fileRoots) in rootsByFile.sorted(by: { $0.key.string < $1.key.string }) {
            let symbols = GeneratedAssetSymbols.symbols(in: fileRoots, kinds: kinds)
            let assets = Dictionary(grouping: symbols) { AssetKey(kind: $0.1, symbolName: $0.0.name) }
            var assetNamesByKind: [AssetCatalogSymbolKind: [String: String]] = [:]

            for (key, assetSymbols) in assets.sorted(by: { $0.key < $1.key }) {
                let declarations = assetSymbols.map(\.0).sorted()

                if declarations.contains(where: graph.isUsed) {
                    declarations.forEach(graph.markUsed)
                    continue
                }

                let resource = declarations.first { $0.parent?.name == key.kind.resourceTypeName } ?? declarations[0]

                for declaration in declarations where declaration != resource {
                    graph.markIgnored(declaration)
                }

                if assetNamesByKind[key.kind] == nil {
                    assetNamesByKind[key.kind] = try GeneratedAssetSymbols.assetNames(in: file, kind: key.kind)
                }

                let assetName = assetNamesByKind[key.kind]?[key.symbolName]
                let assetPaths = assetName.map { locator.assetPaths(named: $0, kind: key.kind) } ?? []
                graph.markUnusedAssetCatalogSymbol(
                    resource,
                    symbol: AssetCatalogSymbol(kind: key.kind, assetName: assetName, assetPaths: assetPaths)
                )
            }
        }
    }
}
