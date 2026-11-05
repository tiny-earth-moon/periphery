import Configuration
import Foundation
import Shared

/// The `@Observable` macro attaches `@ObservationTracked` to each stored property of the class, which expands into
/// accessors that reference the property and its siblings through key paths (`access(keyPath:)`,
/// `withMutation(keyPath:)`). The compiler indexes these accessors as implicit declarations, which are always
/// retained, so every tracked property would look used and never read or written by explicit code. This mutator drops
/// the references held by the macro-generated accessors, so that only references from explicit code count.
final class ObservationMacroReferenceEliminator: SourceGraphMutator {
    private static let trackedMacroName = "ObservationTracked()"

    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        var removedReferences: Set<Reference> = []
        var observableTypes: Set<Declaration> = []

        for property in graph.declarations(ofKinds: [.varInstance]) where isObservationTracked(property) {
            if let type = property.parent {
                observableTypes.insert(type)
            }

            for accessor in property.declarations where accessor.isImplicit && accessor.kind.isAccessorKind {
                for reference in accessor.references {
                    removedReferences.insert(reference)
                    graph.remove(reference)
                }
            }
        }

        restoreCollidingReferences(removedReferences, in: observableTypes)
    }

    // MARK: - Private

    /// Every reference in the macro expansion is located at the `@Observable` attribute, and references are equal when
    /// their USR, location and kind are. A property observer is moved by the macro onto the `_property` backing
    /// storage, so a read from its body can be equal to a reference held by the tracked accessors, and removing the
    /// latter also dropped it from the graph. Such references held by other declarations are added back.
    private func restoreCollidingReferences(_ removedReferences: Set<Reference>, in types: Set<Declaration>) {
        guard !removedReferences.isEmpty else { return }

        for declaration in types.flatMapSet(\.descendentDeclarations) {
            for reference in declaration.references where removedReferences.contains(reference) {
                graph.add(reference)
            }
        }
    }

    private func isObservationTracked(_ property: Declaration) -> Bool {
        property.references.contains { $0.declarationKind == .macro && $0.name == Self.trackedMacroName }
    }
}
