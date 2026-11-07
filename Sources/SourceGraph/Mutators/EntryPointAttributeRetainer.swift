import Configuration
import Foundation
import Shared

final class EntryPointAttributeRetainer: SourceGraphMutator {
    private static let entryPointAttributes: Set<String> = ["main", "UIApplicationMain", "NSApplicationMain"]

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
            .filter { $0.hasAttribute(in: Self.entryPointAttributes) }
            .forEach {
                retainEntryPoint($0)

                if $0.hasAttribute(named: "main") {
                    retainMainFunction(in: $0)
                }
            }
    }

    /// `@main` can be applied to an extension of the entry point type. Extensions are folded into the extended type,
    /// and only remain reachable through the graph's extension index.
    private func retainTypesWithAttributedExtensions() {
        for (extendedDeclaration, extensions) in graph.extensions {
            for extensionDeclaration in extensions
                where extensionDeclaration.hasAttribute(named: "main")
            {
                retainEntryPoint(extendedDeclaration)
                graph.markRetainedWithAncestors(
                    extensionDeclaration,
                    reason: RetentionReason(Self.self, "@main entry point"),
                    ancestorReason: RetentionReason(Self.self, "encloses a @main entry point")
                )
                retainMainFunction(in: extensionDeclaration)
            }
        }
    }

    private func retainEntryPoint(_ declaration: Declaration) {
        graph.markRetainedWithAncestors(
            declaration,
            reason: RetentionReason(Self.self, Self.entryPointDetail(of: declaration)),
            ancestorReason: RetentionReason(Self.self, "encloses an entry point")
        )
        graph.markMainAttributed(declaration)
    }

    private static func entryPointDetail(of declaration: Declaration) -> String {
        let attribute = ["main", "UIApplicationMain", "NSApplicationMain"].first { declaration.hasAttribute(named: $0) }
        return "@\(attribute ?? "main") entry point"
    }

    /// @main requires a static main() function.
    private func retainMainFunction(in declaration: Declaration) {
        declaration.declarations
            .filter { $0.kind == .functionMethodStatic && $0.name == "main()" }
            .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "static main() of a @main entry point")) }
    }
}
