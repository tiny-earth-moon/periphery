extension RedundantExplicitPublicAccessibilityMarker {
    /// A public protocol that is not directly referenced cross-module may still be exposed by a public member declared
    /// within an extension that is accessed on a conforming type.
    ///
    ///     // TargetA
    ///     public protocol MyProtocol {}
    ///     public extension MyProtocol {
    ///         func someExtensionFunc() {}
    ///     }
    ///     public class MyClass: MyProtocol {}
    ///
    ///     // TargetB
    ///     let cls = MyClass()
    ///     cls.someExtensionFunc()
    ///
    func isProtocolIndirectlyReferencedCrossModuleByExtensionMember(_ decl: Declaration) -> Bool {
        guard decl.kind == .protocol else { return false }

        return graph.references(to: decl)
            .lazy
            .compactMap { ref -> Declaration? in
                guard let parent = ref.parent else { return nil }

                if parent.kind == .extensionProtocol, parent.name == decl.name {
                    return parent
                }

                return nil
            }
            .contains {
                $0.declarations.contains {
                    $0.accessibility.value == .public && isReferencedCrossModule($0)
                }
            }
    }

    /// A public protocol whose public extension supplies the witness of a requirement of another public protocol,
    /// external or local, must stay public while a public type conforms through it, because the witness must be as
    /// accessible as that type's conformance. The index relates the witness to the requirement through a related
    /// reference, which has no local declaration when the requirement is external.
    ///
    ///     public protocol Named: Identifiable {}
    ///     public extension Named {
    ///         var id: String { name }
    ///     }
    ///     public struct Item: Named {}
    ///
    func isProtocolWitnessingPublicRequirementForPublicConformer(_ decl: Declaration) throws -> Bool {
        guard decl.kind == .protocol else { return false }

        let witnessesPublicRequirement = graph.references(to: decl).contains { ref in
            guard let parent = ref.parent, parent.kind == .extensionProtocol, parent.name == decl.name else { return false }

            return parent.declarations.contains {
                $0.accessibility.value == .public && isPublicRequirementWitness($0, declaredBy: decl)
            }
        }

        guard witnessesPublicRequirement else { return false }

        return try hasPubliclyAccessibleConformer(decl)
    }

    /// Whether the member witnesses a requirement of an external protocol, or of a publicly accessible local protocol
    /// other than the one it extends, whose members it merely provides defaults for.
    private func isPublicRequirementWitness(_ member: Declaration, declaredBy protocolDecl: Declaration) -> Bool {
        guard member.kind.isProtocolMemberKind else { return false }

        return member.related.contains {
            guard $0.name == member.name, $0.declarationKind.isProtocolMemberConformingKind else { return false }
            guard let requirement = graph.declaration(withUsr: $0.usr) else { return true }
            guard let owner = requirement.parent else { return false }

            return owner != protocolDecl
                && owner.kind == .protocol
                && owner.accessibility.isAccessibleCrossModule
                && !graph.redundantPublicAccessibility.keys.contains(owner)
        }
    }

    /// Whether a publicly accessible type conforms to the protocol, directly, in an extension, or through a publicly
    /// accessible protocol that refines it.
    private func hasPubliclyAccessibleConformer(_ protocolDecl: Declaration) throws -> Bool {
        var visited: Set<Declaration> = [protocolDecl]
        var pending = [protocolDecl]

        while let current = pending.popLast() {
            for ref in graph.references(to: current) where ref.kind == .related {
                guard let parent = ref.parent, visited.insert(parent).inserted,
                      try isEffectivelyPublic(parent)
                else { continue }

                if parent.kind == .protocol {
                    pending.append(parent)
                } else if parent.kind == .extensionProtocol {
                    if let extendedProtocol = try graph.extendedDeclaration(forExtension: parent) {
                        pending.append(extendedProtocol)
                    }
                } else {
                    return true
                }
            }
        }

        return false
    }
}
