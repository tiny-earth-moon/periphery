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
        for property in graph.declarations(ofKinds: [.varInstance]) where isObservationTracked(property) {
            for accessor in property.declarations where accessor.isImplicit && accessor.kind.isAccessorKind {
                for reference in accessor.references {
                    graph.remove(reference)
                }
            }
        }
    }

    // MARK: - Private

    private func isObservationTracked(_ property: Declaration) -> Bool {
        property.references.contains { $0.declarationKind == .macro && $0.name == Self.trackedMacroName }
    }
}
