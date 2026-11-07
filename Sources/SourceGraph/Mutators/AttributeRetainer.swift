import Configuration
import Foundation
import Shared

/// Retains the declarations that carry one of the attributes listed in `retain_attributes`, optionally limited
/// to declaration kinds with `Attribute:kind1,kind2`.
final class AttributeRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        let rules = try AttributeRetentionRule.resolve(configuration)
        guard !rules.isEmpty else { return }

        for declaration in graph.allDeclarations where !declaration.attributes.isEmpty {
            if rules.contains(where: { $0.retains(declaration) }) {
                graph.markRetained(declaration, reason: RetentionReason(Self.self, "retain_attributes"))
            }
        }
    }
}

public struct AttributeRetentionRule: Equatable {
    public let attribute: String
    /// `nil` retains every kind of declaration.
    public let kinds: [String]?

    func retains(_ declaration: Declaration) -> Bool {
        guard declaration.hasAttribute(named: attribute) else { return false }
        guard let kinds else { return true }

        return kinds.contains { declaration.kind.matches(identifier: $0) }
    }

    /// Resolves the `retain_attributes` entries, throwing a usage error for any malformed entry or unknown kind.
    public static func resolve(_ configuration: Configuration) throws -> [AttributeRetentionRule] {
        try configuration.retainAttributes.map(parse)
    }

    static func parse(_ entry: String) throws -> AttributeRetentionRule {
        let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var attribute = parts[0].trimmingCharacters(in: .whitespaces)

        if attribute.hasPrefix("@") {
            attribute.removeFirst()
        }

        guard !attribute.isEmpty else {
            throw PeripheryError.usageError("retain_attributes: missing attribute name in '\(entry)'. Expected '<attribute>' or '<attribute>:kind1,kind2'.")
        }
        guard parts.count == 2 else {
            return AttributeRetentionRule(attribute: attribute, kinds: nil)
        }

        let kinds = parts[1].split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }

        for kind in kinds where !Declaration.Kind.isValidIdentifier(kind) {
            let valid = Declaration.Kind.identifiers.sorted().joined(separator: ", ")
            throw PeripheryError.usageError("retain_attributes: unknown declaration kind '\(kind)' for '\(attribute)'. Valid kinds: \(valid).")
        }

        return AttributeRetentionRule(attribute: attribute, kinds: kinds)
    }
}
