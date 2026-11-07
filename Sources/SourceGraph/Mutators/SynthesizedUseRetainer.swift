import Configuration
import Foundation
import Shared

/// Retains the stored properties of types whose values are described through reflection (`print`,
/// `String(describing:)`, string interpolation, `dump`, ...), which read them without any reference in the index
/// store. Opt-in through `retain_synthesized_uses`.
final class SynthesizedUseRetainer: SourceGraphMutator {
    private static let descriptionProtocols: Set = [
        "CustomStringConvertible", "CustomDebugStringConvertible", "TextOutputStreamable", "CustomReflectable",
    ]
    private static let dumpProtocols: Set = ["CustomReflectable"]

    private let graph: SourceGraph
    private let configuration: Configuration
    private var retainedTypes: Set<RetainedType> = []
    private lazy var typesByName: [String: [Declaration]] = Dictionary(
        grouping: graph.declarations(ofKinds: [.struct, .class]),
        by: \.name
    )

    private struct RetainedType: Hashable {
        let declaration: Declaration
        let kind: SynthesizedUse.Kind
    }

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        guard configuration.retainSynthesizedUses, !graph.synthesizedUses.isEmpty else { return }

        let uses = graph.synthesizedUses
        let locations = Set(uses.compactMap(\.location))
        let referencesByLocation = Dictionary(
            grouping: graph.allReferences.filter { locations.contains($0.location) },
            by: \.location
        )

        for use in uses {
            if let location = use.location {
                for reference in referencesByLocation[location, default: []] {
                    for type in types(of: reference) {
                        retainProperties(of: type, kind: use.kind)
                    }
                }
            }

            if let typeName = use.typeName {
                for type in typesByName[typeName, default: []] {
                    retainProperties(of: type, kind: use.kind)
                }
            }
        }
    }

    // MARK: - Private

    private func types(of reference: Reference) -> [Declaration] {
        guard let declaration = graph.declaration(withUsr: reference.usr) else { return [] }

        switch declaration.kind {
        case .struct, .class:
            return [declaration]
        case .functionConstructor:
            return declaration.parent.map { [$0] } ?? []
        default:
            guard declaration.kind.isVariableKind, let declaredType = declaration.declaredType else { return [] }

            return typesByName[SynthesizedUse.baseTypeName(declaredType), default: []]
        }
    }

    private func retainProperties(of type: Declaration, kind: SynthesizedUse.Kind) {
        guard type.kind == .struct || (kind == .dump && type.kind == .class),
              retainedTypes.insert(RetainedType(declaration: type, kind: kind)).inserted,
              !providesCustomDescription(type, kind: kind)
        else { return }

        for property in type.declarations where property.kind == .varInstance && isStored(property) {
            graph.markRetained(property, reason: RetentionReason(Self.self, "retain_synthesized_uses, described through reflection"))

            // Reflection describes stored values recursively.
            if let declaredType = property.declaredType {
                for nestedType in typesByName[SynthesizedUse.baseTypeName(declaredType), default: []] {
                    retainProperties(of: nestedType, kind: kind)
                }
            }
        }
    }

    private func providesCustomDescription(_ type: Declaration, kind: SynthesizedUse.Kind) -> Bool {
        let protocols = kind == .dump ? Self.dumpProtocols : Self.descriptionProtocols
        let conformances = graph.inheritedTypeReferences(of: type).union(
            graph.extensions[type, default: []].flatMapSet { graph.inheritedTypeReferences(of: $0) }
        )

        return conformances.contains { protocols.contains($0.name) }
    }

    /// Computed properties have explicit accessors, whereas the accessors of stored properties are implicit.
    private func isStored(_ property: Declaration) -> Bool {
        property.declarations.allSatisfy { !$0.kind.isAccessorKind || $0.isImplicit }
    }
}
