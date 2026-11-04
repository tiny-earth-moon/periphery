import Configuration
import Foundation
import Shared

/// Retains the Metal functions of `.metal` files that a Swift string literal names, and records the literals naming
/// a function that no `.metal` file declares.
///
/// An expression that is not a plain string literal may name any function, so it retains every Metal function.
final class MetalFunctionRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        guard configuration.detectUnusedMetalFunctions else { return }

        let references = graph.metalFunctionNameReferences
        let names = Set(references.compactMap(\.name))
        let retainsEverything = references.contains { $0.name == nil }

        for declaration in graph.declarations(ofKind: .metalFunction) where retainsEverything || names.contains(declaration.name) {
            graph.markRetained(declaration)
        }

        guard graph.declaredMetalFunctionNamesAreComplete else { return }

        // A library compiled or loaded at run time may declare any function.
        if let site = graph.metalRuntimeLibrarySites.min() {
            graph.logMetalRuntimeLibrary(site)
            return
        }

        let declaredNames = graph.declaredMetalFunctionNames

        for reference in references.sorted(by: { $0.location < $1.location }) {
            guard let name = reference.name, !declaredNames.contains(name) else { continue }

            graph.markMissingMetalFunction(named: name, at: reference.location)
        }
    }
}
