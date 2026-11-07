import Configuration
import Foundation
import Shared

/// Retains every declaration of the analyzed `GeneratedAssetSymbols.swift` files except the asset symbols, so that
/// only unused assets can be reported from these files.
final class AssetCatalogSymbolRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        let kinds = AssetCatalogSymbolKind.detected(by: configuration)
        guard !kinds.isEmpty else { return }

        for declaration in GeneratedAssetSymbols.rootDeclarations(in: graph, configuration: configuration) {
            retainNonSymbols(declaration, kinds: kinds)
        }
    }

    // MARK: - Private

    private func retainNonSymbols(_ declaration: Declaration, kinds: [AssetCatalogSymbolKind]) {
        guard GeneratedAssetSymbols.symbolKind(of: declaration, in: kinds) == nil else { return }

        graph.markRetained(declaration, reason: RetentionReason(Self.self, "asset catalog symbol"))
        graph.markRetained(declaration.unusedParameters, reason: RetentionReason(Self.self, "asset catalog symbol"))

        for child in declaration.declarations {
            retainNonSymbols(child, kinds: kinds)
        }
    }
}
