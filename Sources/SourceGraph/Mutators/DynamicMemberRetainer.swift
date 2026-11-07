import Configuration
import Foundation
import Shared

final class DynamicMemberRetainer: SourceGraphMutator {
    /// The methods a call to a `@dynamicCallable` value is lowered to, which the index records no reference to.
    static let dynamicCallableMethodNames: Set<String> = [
        "dynamicallyCall(withArguments:)", "dynamicallyCall(withKeywordArguments:)",
    ]
    private static var reason: RetentionReason {
        RetentionReason(DynamicMemberRetainer.self, "dynamic member lookup or dynamic callable requirement")
    }

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
                graph.markRetained(decl, reason: Self.reason)
            }
        }

        // Retain the methods that a call to a @dynamicCallable value is lowered to, by name for the same reason.
        for decl in graph.declarations(ofKind: .functionMethodInstance) where Self.dynamicCallableMethodNames.contains(decl.name) {
            graph.markRetained(decl, reason: Self.reason)
            graph.markRetained(decl.unusedParameters, reason: Self.reason)
        }

        for decl in graph.declarations(ofKinds: Declaration.Kind.functionKinds.union(Declaration.Kind.variableKinds)) where decl.hasAttribute(named: "_dynamicReplacement") {
            graph.markRetained(decl, reason: Self.reason)
        }
    }
}
