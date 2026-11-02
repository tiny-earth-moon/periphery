import Configuration
import Foundation
import Shared

/// Marks stored optional properties that are read but never assigned, and are thus always nil.
///
/// Reads and writes are taken from the index: every direct access of a stored property is recorded as a reference
/// to the property together with an implicit reference to its getter (read) or setter (write) at the same location.
/// A property reference without an accompanying accessor reference is an access whose kind cannot be determined, so
/// such properties are never reported. So are properties referenced by a key path component, other than the direct
/// argument of a `keyPath:` subscript: the index records such a component as a read, but a stored or forwarded
/// writable key path may write the property.
final class UnassignedOptionalPropertyMarker: SourceGraphMutator {
    private static let candidateKinds: Set<Declaration.Kind> = [.varInstance, .varStatic, .varClass, .varGlobal]
    /// Modifiers of properties that are assigned by the runtime, or whose accesses are not visible to the index.
    private static let runtimeAssignedModifiers: Set<String> = ["weak", "unowned", "dynamic", "lazy", "override"]
    /// Protocols whose conformances may assign properties through synthesized or runtime code that is not indexed.
    private static let decodingProtocols: Set<String> = ["NSCoding", "NSSecureCoding"]

    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        guard configuration.enableUnassignedOptionalAnalysis else { return }

        for property in graph.declarations(ofKinds: Self.candidateKinds) where isUnassignedOptional(property) {
            graph.markUnassignedOptionalProperty(property)
        }
    }

    // MARK: - Private

    private func isUnassignedOptional(_ property: Declaration) -> Bool {
        guard property.isOptionalType,
              !property.hasNonNilInitialValue,
              !property.isImplicit,
              property.attributes.isEmpty,
              property.modifiers.isDisjoint(with: Self.runtimeAssignedModifiers),
              !property.isObjcAccessible,
              !property.isComplexProperty,
              !graph.isRetained(property),
              !isDeclaredInProtocolOrDecodableType(property),
              // Protocol requirements are written through the protocol's own setter.
              !graph.references(to: property).contains(where: { $0.parent?.parent?.kind == .protocol }),
              // Constants have no setter: they must be initialized, so they are always assigned.
              let setter = property.declarations.first(where: { $0.kind == .functionAccessorSetter }),
              let getter = property.declarations.first(where: { $0.kind == .functionAccessorGetter })
        else { return false }

        let writingAccessors = property.declarations.filter { $0.kind.isAccessorKind && $0 != getter }
        let isWritten = writingAccessors.contains { hasNonRetainedReferences($0) }
        let isRead = hasNonRetainedReferences(getter)

        return isRead && !isWritten && !hasUnclassifiedAccess(property, getter: getter, setter: setter)
    }

    private func hasNonRetainedReferences(_ declaration: Declaration) -> Bool {
        graph.references(to: declaration).contains { $0.kind != .retained }
    }

    private func hasUnclassifiedAccess(_ property: Declaration, getter: Declaration, setter: Declaration) -> Bool {
        let accessorLocations = graph.references(to: getter).union(graph.references(to: setter)).mapSet(\.location)
        let keyPathLocations = graph.keyPathComponentLocations

        return graph.references(to: property).contains {
            $0.kind == .normal && (!accessorLocations.contains($0.location) || keyPathLocations.contains($0.location))
        }
    }

    private func isDeclaredInProtocolOrDecodableType(_ property: Declaration) -> Bool {
        guard let parent = property.parent else { return false }

        // Extensions of indexed types are folded into the extended type by ExtensionReferenceBuilder, remaining
        // extensions extend external types whose conformances are unknown.
        if parent.kind == .protocol || parent.kind.isExtensionKind {
            return true
        }

        if graph.isCodable(parent) {
            return true
        }

        return graph.inheritedTypeReferences(of: parent).contains {
            [.protocol, .typealias].contains($0.declarationKind) && Self.decodingProtocols.contains($0.name)
        }
    }
}
