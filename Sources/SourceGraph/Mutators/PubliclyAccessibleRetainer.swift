import Configuration
import Foundation
import Shared

final class PubliclyAccessibleRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration
    private let noRetainSPIAttributes: [DeclarationAttribute]

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
        noRetainSPIAttributes = configuration.noRetainSPI.map { DeclarationAttribute(name: "_spi", arguments: $0) }
    }

    func mutate() {
        guard configuration.retainsPublicDeclarations else { return }

        let declarations = Declaration.Kind.accessibleKinds.union([.macro, .associatedtype]).flatMap {
            graph.declarations(ofKind: $0)
        }

        let publicDeclarations = declarations.filter {
            ($0.accessibility.value == .public || $0.accessibility.value == .open)
                && configuration.retainsPublicDeclarations(inModules: $0.location.file.modules)
        }

        // Only filter if noRetainSPI is configured (performance optimization)
        let declarationsToRetain: [Declaration] = if configuration.noRetainSPI.isEmpty {
            publicDeclarations
        } else {
            publicDeclarations.filter { decl in
                decl.attributes.isDisjoint(with: noRetainSPIAttributes)
            }
        }

        let reason = RetentionReason(Self.self, configuration.retainPublic ? "retain_public" : "retain_public_modules")
        declarationsToRetain.forEach { graph.markRetained($0, reason: reason) }

        // Enum cases inherit the accessibility of the enum.
        declarationsToRetain
            .lazy
            .filter { $0.kind == .enum }
            .flatMap(\.declarations)
            .filter { $0.kind == .enumelement }
            .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "\(reason.detail ?? ""), case of a public enum")) }
    }
}
