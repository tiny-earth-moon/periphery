import Configuration
import Foundation
import Shared

enum AssignOnlyPropertyAnalyzer {
    static func isAssignOnlyProperty(
        _ property: Declaration,
        graph: SourceGraph,
        configuration: Configuration
    ) -> Bool {
        let defaultRetainedTypes = ["AnyCancellable", "Set<AnyCancellable>", "[AnyCancellable]", "NSKeyValueObservation"]
        let retainAssignOnlyPropertyTypes = defaultRetainedTypes + configuration.retainAssignOnlyPropertyTypes.map {
            PropertyTypeSanitizer.sanitize($0)
        }

        guard !configuration.retainAssignOnlyProperties,
              property.kind.isVariableKind,
              let type = property.declaredType ?? property.inferredType,
              !isRetainedType(type, retainedTypes: retainAssignOnlyPropertyTypes),
              property.attributes.isEmpty,
              !property.isComplexProperty,
              // A protocol property can technically be assigned and never used when the protocol is
              // used as an existential type, however communicating that succinctly would be very
              // tricky, and most likely just lead to confusion. Here we filter out protocol
              // properties and thus restrict this analysis only to concrete properties.
              property.parent?.kind != .protocol,
              !graph.references(to: property).contains(where: { $0.parent?.parent?.kind == .protocol }),
              let setter = property.declarations.first(where: { $0.kind == .functionAccessorSetter }),
              let getter = property.declarations.first(where: { $0.kind == .functionAccessorGetter }),
              graph.references(to: setter).contains(where: { $0.kind != .retained }),
              !graph.references(to: getter).contains(where: { $0.kind != .retained })
        else { return false }

        return true
    }

    /// Inferred types are fully qualified (`Swift.Set<Combine.AnyCancellable>`), so a type is also
    /// retained when it matches once module and parent type qualifiers are stripped from both sides.
    private static func isRetainedType(_ type: String, retainedTypes: [String]) -> Bool {
        if retainedTypes.contains(type) {
            return true
        }

        let unqualifiedType = unqualified(type)
        return retainedTypes.contains { unqualified($0) == unqualifiedType }
    }

    private static func unqualified(_ type: String) -> String {
        PropertyTypeSanitizer.sanitize(
            type.replacingOccurrences(of: #"[A-Za-z_][A-Za-z0-9_]*\."#, with: "", options: .regularExpression)
        )
    }
}

final class AssignOnlyPropertyReferenceEliminator: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        guard !configuration.retainAssignOnlyProperties else { return }

        for property in graph.declarations(ofKinds: Declaration.Kind.variableKinds) {
            if AssignOnlyPropertyAnalyzer.isAssignOnlyProperty(property, graph: graph, configuration: configuration) {
                if graph.isRetained(property) {
                    graph.markSuppressedAssignOnlyProperty(property)
                } else {
                    graph.markAssignOnlyProperty(property)
                }
            }
        }
    }
}
