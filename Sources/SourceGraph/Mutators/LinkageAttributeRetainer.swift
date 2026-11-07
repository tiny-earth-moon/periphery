import Configuration
import Foundation
import Shared

/// Retains the declarations that exist for callers the index cannot see: C code, the linker, the runtime or a
/// section reader.
final class LinkageAttributeRetainer: SourceGraphMutator {
    /// Attributes that export a function to C or C++, or define the symbol it is linked under.
    private static let exportingFunctionAttributes: Set<String> = ["c", "_cdecl", "_expose"]
    /// Attributes that keep a function or a variable in the binary, or place it in a named section.
    private static let linkerVisibleAttributes: Set<String> = ["used", "_used", "section", "_section"]
    /// Attributes of a declaration implemented on behalf of an imported C or Objective-C declaration.
    private static let implementationAttributes: Set<String> = ["implementation", "_objcImplementation"]
    private static var reason: RetentionReason {
        RetentionReason(LinkageAttributeRetainer.self, "linkage attribute (@_cdecl, @_silgen_name, @_used or @_section)")
    }

    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        for decl in graph.allDeclarations where !decl.attributes.isEmpty {
            if isImplementation(decl) {
                graph.markRetained(decl, reason: Self.reason)
                graph.markRetained(decl.descendentDeclarations, reason: Self.reason)
            } else if isLinkageVisible(decl) {
                graph.markRetained(decl, reason: Self.reason)
                graph.markRetained(decl.unusedParameters, reason: Self.reason)
            }
        }
    }

    // MARK: - Private

    private func isImplementation(_ decl: Declaration) -> Bool {
        guard decl.kind.isExtensionKind || [.class, .struct, .enum].contains(decl.kind) else { return false }

        return decl.hasAttribute(in: Self.implementationAttributes)
    }

    private func isLinkageVisible(_ decl: Declaration) -> Bool {
        if decl.kind.isFunctionKind {
            // Only a definition provides a `_silgen_name` symbol. A bodyless declaration imports it.
            return decl.hasAttribute(in: Self.exportingFunctionAttributes)
                || (decl.hasBody && decl.hasAttribute(named: "_silgen_name"))
                || decl.hasAttribute(in: Self.linkerVisibleAttributes)
        }

        return decl.kind.isVariableKind && decl.hasAttribute(in: Self.linkerVisibleAttributes)
    }
}
