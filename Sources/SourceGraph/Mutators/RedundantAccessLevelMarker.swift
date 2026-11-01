import Configuration
import Shared

/// Identifies explicit access modifiers that are identical to the access level the declaration would get without
/// them, i.e. the default access level of its enclosing context.
///
/// - At the top level, members default to `internal`.
/// - In a type, members default to `internal`, or to `fileprivate` in a `private` or `fileprivate` top-level type.
/// - In an extension with an access modifier, members default to that modifier; `private` and `fileprivate` members
///   of a `private` extension are both redundant, as the extension already restricts them to the file.
/// - In an extension without an access modifier, members default like in the extended type.
///
/// `open` is never reported, nor are setter access modifiers such as `private(set)`. `private` members of a type
/// are not redundant: they restrict access to the type's declarations, which is narrower than the type's default.
final class RedundantAccessLevelMarker: SourceGraphMutator {
    private static let containerKinds: Set<Declaration.Kind> = Declaration.Kind.extensionKinds.union([.class, .struct, .enum])

    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        guard configuration.enableRedundantAccessLevelAnalysis else { return }

        for decl in graph.rootDeclarations where !decl.isImplicit {
            if decl.accessibility.isExplicitly(.internal) {
                graph.markRedundantAccessLevel(decl, accessibility: .internal, context: nil)
            }

            try validateMembers(of: decl)
        }
    }

    // MARK: - Private

    private func validateMembers(of container: Declaration) throws {
        guard Self.containerKinds.contains(container.kind) else { return }

        let memberDefault = try memberDefaultAccessibility(in: container)

        for member in container.declarations where !member.isImplicit && !member.kind.isAccessorKind {
            if let memberDefault,
               member.accessibility.isExplicit,
               isRedundant(member.accessibility.value, memberDefault: memberDefault, container: container)
            {
                graph.markRedundantAccessLevel(member, accessibility: member.accessibility.value, context: memberDefault)
            }

            try validateMembers(of: member)
        }
    }

    private func isRedundant(_ accessibility: Accessibility, memberDefault: Accessibility, container: Declaration) -> Bool {
        guard accessibility != .open else { return false }

        if accessibility == memberDefault {
            return true
        }

        // Members of a private extension are fileprivate.
        return accessibility == .fileprivate && memberDefault == .private && container.kind.isExtensionKind
    }

    /// The access level of a member declared without access modifier in `container`, or nil when it cannot be
    /// expressed with a single modifier (e.g. members of a nested private type, or of a `package` declaration).
    private func memberDefaultAccessibility(in container: Declaration) throws -> Accessibility? {
        guard !container.modifiers.contains("package") else { return nil }

        if container.kind.isExtensionKind {
            if container.accessibility.isExplicit {
                return container.accessibility.value
            }

            guard container.kind.extendedKind != nil else { return nil }

            // Extensions of external types are assumed to extend publicly accessible types.
            guard let extendedDecl = try graph.extendedDeclaration(forExtension: container) else { return .internal }

            return try typeMemberDefaultAccessibility(of: extendedDecl)
        }

        return try typeMemberDefaultAccessibility(of: container)
    }

    private func typeMemberDefaultAccessibility(of typeDecl: Declaration) throws -> Accessibility? {
        switch try accessibility(of: typeDecl) {
        case .open, .public, .internal:
            .internal
        case .fileprivate:
            .fileprivate
        case .private:
            // A private top-level type is fileprivate; a private nested type is private to its enclosing scope.
            typeDecl.parent == nil ? .fileprivate : nil
        case nil:
            nil
        }
    }

    /// The access level of a type, either explicit or inherited from its enclosing context.
    private func accessibility(of typeDecl: Declaration) throws -> Accessibility? {
        guard !typeDecl.modifiers.contains("package") else { return nil }

        if typeDecl.accessibility.isExplicit {
            return typeDecl.accessibility.value
        }

        guard let parent = typeDecl.parent else { return .internal }

        let inherited = try memberDefaultAccessibility(in: parent)
        // A type declared in a private extension is fileprivate.
        return inherited == .private && parent.kind.isExtensionKind ? .fileprivate : inherited
    }
}
