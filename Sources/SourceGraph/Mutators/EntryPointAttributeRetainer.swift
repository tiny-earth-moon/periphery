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
                graph.markRetained(extensionDeclaration, reason: RetentionReason(Self.self, "@main entry point"))
                retainMainFunction(in: extensionDeclaration)

                for ancestralDeclaration in extensionDeclaration.ancestralDeclarations {
                    graph.markRetained(ancestralDeclaration, reason: RetentionReason(Self.self, "encloses a @main entry point"))
                }
            }
        }
    }

    private func retainEntryPoint(_ declaration: Declaration) {
        graph.markRetained(declaration, reason: RetentionReason(Self.self, Self.entryPointDetail(of: declaration)))
        graph.markMainAttributed(declaration)

        for ancestralDeclaration in declaration.ancestralDeclarations {
            graph.markRetained(ancestralDeclaration, reason: RetentionReason(Self.self, "encloses an entry point"))
        }
    }

    private static func entryPointDetail(of declaration: Declaration) -> String {
        let attribute = ["main", "UIApplicationMain", "NSApplicationMain"].first { name in
            declaration.attributes.contains { $0.name == name }
        }
        return "@\(attribute ?? "main") entry point"
    }

    /// @main requires a static main() function.
    private func retainMainFunction(in declaration: Declaration) {
        declaration.declarations
            .filter { $0.kind == .functionMethodStatic && $0.name == "main()" }
            .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "static main() of a @main entry point")) }
    }
}
