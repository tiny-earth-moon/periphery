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

    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        for decl in graph.allDeclarations where !decl.attributes.isEmpty {
            if isImplementation(decl) {
                graph.markRetained(decl, reason: RetentionReason(Self.self, "linkage attribute (@_cdecl, @_silgen_name, @_used or @_section)"))
                decl.descendentDeclarations.forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "linkage attribute (@_cdecl, @_silgen_name, @_used or @_section)")) }
            } else if isLinkageVisible(decl) {
                graph.markRetained(decl, reason: RetentionReason(Self.self, "linkage attribute (@_cdecl, @_silgen_name, @_used or @_section)"))
                decl.unusedParameters.forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "linkage attribute (@_cdecl, @_silgen_name, @_used or @_section)")) }
            }
        }
    }

    // MARK: - Private

    private func isImplementation(_ decl: Declaration) -> Bool {
        guard decl.kind.isExtensionKind || [.class, .struct, .enum].contains(decl.kind) else { return false }

        return hasAttribute(in: Self.implementationAttributes, decl)
    }

    private func isLinkageVisible(_ decl: Declaration) -> Bool {
        let isFunction = decl.kind.isFunctionKind

        if isFunction {
            if hasAttribute(in: Self.exportingFunctionAttributes, decl) {
                return true
            }

            // Only a definition provides the symbol. A bodyless declaration imports it.
            if decl.hasBody, hasAttribute(in: ["_silgen_name"], decl) {
                return true
            }
        }

        guard isFunction || decl.kind.isVariableKind else { return false }

        return hasAttribute(in: Self.linkerVisibleAttributes, decl)
    }

    private func hasAttribute(in names: Set<String>, _ decl: Declaration) -> Bool {
        decl.attributes.contains { names.contains($0.name) }
    }
}
