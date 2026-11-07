import Configuration
import Foundation
import Shared

final class PropertyWrapperRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let specialProperties = ["wrappedValue", "projectedValue"]
    private let parameterWrapperInitializerPrefixes = ["init(wrappedValue:", "init(projectedValue:"]

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        for decl in graph.declarations(ofKinds: Declaration.Kind.toplevelAttributableKind) where decl.attributes.contains(where: { $0.name == "propertyWrapper" }) {
            decl.declarations
                .filter { $0.kind == .varInstance && specialProperties.contains($0.name) }
                .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "property wrapper requirement")) }

            // A wrapper applied to a parameter is initialized by the compiler at every call site, from the argument
            // or from a projected value passed as `$label:`, which the index store does not record as a reference to
            // the initializer.
            if graph.parameterAttributeNames.contains(decl.name) {
                decl.declarations
                    .filter { $0.kind == .functionConstructor && isParameterWrapperInitializer($0) }
                    .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "property wrapper requirement")) }
            }
        }
    }

    private func isParameterWrapperInitializer(_ decl: Declaration) -> Bool {
        parameterWrapperInitializerPrefixes.contains { decl.name.hasPrefix($0) }
    }
}
