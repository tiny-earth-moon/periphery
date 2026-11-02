import Configuration
import Foundation
import Shared

final class DynamicMemberRetainer: SourceGraphMutator {
    /// The methods a call to a `@dynamicCallable` value is lowered to, which the index records no reference to.
    static let dynamicCallableMethodNames: Set<String> = [
        "dynamicallyCall(withArguments:)", "dynamicallyCall(withKeywordArguments:)",
    ]

    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() throws {
        // Retain all subscript(dynamicMember:) declarations. This signature is specific to
        // @dynamicMemberLookup and may be declared in extensions of external types where we
        // cannot verify the attribute exists.
        for decl in graph.declarations(ofKind: .functionSubscript) {
            if decl.name == "subscript(dynamicMember:)" {
                graph.markRetained(decl)
            }
        }

        // Retain the methods that a call to a @dynamicCallable value is lowered to, by name for the same reason.
        for decl in graph.declarations(ofKind: .functionMethodInstance) where Self.dynamicCallableMethodNames.contains(decl.name) {
            graph.markRetained(decl)
            decl.unusedParameters.forEach { graph.markRetained($0) }
        }

        for decl in graph.declarations(ofKinds: Declaration.Kind.functionKinds.union(Declaration.Kind.variableKinds)) {
            if decl.attributes.contains(where: { $0.name == "_dynamicReplacement" }) {
                graph.markRetained(decl)
            }
        }
    }
}
