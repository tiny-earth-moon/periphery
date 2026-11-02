import Configuration
import Foundation
import Shared

final class EntryPointAttributeRetainer: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        retainAttributedTypes()
        retainTypesWithAttributedExtensions()
    }

    // MARK: - Private

    private func retainAttributedTypes() {
        graph
            .declarations(ofKinds: [.class, .struct, .enum])
            .lazy
            .filter {
                $0.attributes.contains(where: { $0.name == "NSApplicationMain" }) ||
                    $0.attributes.contains(where: { $0.name == "UIApplicationMain" }) ||
                    $0.attributes.contains(where: { $0.name == "main" })
            }
            .forEach {
                retainEntryPoint($0)

                if $0.attributes.contains(where: { $0.name == "main" }) {
                    retainMainFunction(in: $0)
                }
            }
    }

    /// `@main` can be applied to an extension of the entry point type. Extensions are folded into the extended type,
    /// and only remain reachable through the graph's extension index.
    private func retainTypesWithAttributedExtensions() {
        for (extendedDeclaration, extensions) in graph.extensions {
            for extensionDeclaration in extensions
                where extensionDeclaration.attributes.contains(where: { $0.name == "main" })
            {
                retainEntryPoint(extendedDeclaration)
                graph.markRetained(extensionDeclaration)
                retainMainFunction(in: extensionDeclaration)

                for ancestralDeclaration in extensionDeclaration.ancestralDeclarations {
                    graph.markRetained(ancestralDeclaration)
                }
            }
        }
    }

    private func retainEntryPoint(_ declaration: Declaration) {
        graph.markRetained(declaration)
        graph.markMainAttributed(declaration)

        for ancestralDeclaration in declaration.ancestralDeclarations {
            graph.markRetained(ancestralDeclaration)
        }
    }

    /// @main requires a static main() function.
    private func retainMainFunction(in declaration: Declaration) {
        declaration.declarations
            .filter { $0.kind == .functionMethodStatic && $0.name == "main()" }
            .forEach { graph.markRetained($0) }
    }
}
