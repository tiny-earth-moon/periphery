import Foundation
import Shared
import SourceGraph
import SwiftSyntax

struct TypeNameSourceLocation: Hashable {
    let name: String
    let location: Location
}

struct TypeSyntaxInspector {
    let sourceLocationBuilder: SourceLocationBuilder

    func type(for typeSyntax: TypeSyntax) -> String {
        PropertyTypeSanitizer.sanitize(typeSyntax.trimmed.description)
    }

    func typeNameLocations(for typeSyntax: TypeSyntax) -> Set<TypeNameSourceLocation> {
        types(for: typeSyntax).mapSet {
            .init(name: $0.trimmed.description,
                  location: sourceLocationBuilder.location(at: $0.positionAfterSkippingLeadingTrivia))
        }
    }

    func typeLocations(for typeSyntax: TypeSyntax) -> Set<Location> {
        types(for: typeSyntax).mapSet { sourceLocationBuilder.location(at: $0.positionAfterSkippingLeadingTrivia) }
    }

    /// Whether the type is `T?`, `T!` or `Optional<T>` (optionally qualified as `Swift.Optional<T>`).
    func isOptional(_ typeSyntax: TypeSyntax) -> Bool {
        if typeSyntax.is(OptionalTypeSyntax.self) || typeSyntax.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return true
        }

        if let attributedType = typeSyntax.as(AttributedTypeSyntax.self) {
            return isOptional(attributedType.baseType)
        }

        if let tupleType = typeSyntax.as(TupleTypeSyntax.self),
           tupleType.elements.count == 1,
           let element = tupleType.elements.first,
           element.firstName == nil
        {
            return isOptional(element.type)
        }

        if let identifierType = typeSyntax.as(IdentifierTypeSyntax.self) {
            return identifierType.name.text == "Optional" && identifierType.genericArgumentClause != nil
        }

        if let memberType = typeSyntax.as(MemberTypeSyntax.self),
           memberType.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Swift"
        {
            return memberType.name.text == "Optional" && memberType.genericArgumentClause != nil
        }

        return false
    }

    // MARK: - Private

    func types(for typeSyntax: TypeSyntax) -> Set<TokenSyntax> {
        if let identifierType = typeSyntax.as(IdentifierTypeSyntax.self) {
            // Simple type.
            var result: Set<TokenSyntax> = identifierType.genericArgumentClause?.arguments.flatMapSet {
                guard case let .type(argumentType) = $0.argument else { return [] }

                return types(for: argumentType)
            } ?? []
            return result.inserting(identifierType.name)
        } else if let optionalType = typeSyntax.as(OptionalTypeSyntax.self) {
            // Optional type.
            return types(for: optionalType.wrappedType)
        } else if let memberType = typeSyntax.as(MemberTypeSyntax.self) {
            // Member type.
            return types(for: memberType.baseType)
                .union(memberType.genericArgumentClause?.arguments.flatMapSet {
                    guard case let .type(argumentType) = $0.argument else { return [] }

                    return types(for: argumentType)
                } ?? [])
                .union([memberType.name])
        } else if let tuple = typeSyntax.as(TupleTypeSyntax.self) {
            // Tuple type.
            return tuple.elements.flatMapSet { types(for: $0.type) }
        } else if let funcType = typeSyntax.as(FunctionTypeSyntax.self) {
            // Function type.
            let argumentTypes = funcType.parameters.flatMapSet { types(for: $0.type) }
            let throwTypes = funcType.effectSpecifiers?.throwsClause?.type.map { types(for: $0) } ?? []
            return types(for: funcType.returnClause.type).union(argumentTypes).union(throwTypes)
        } else if let arrayType = typeSyntax.as(ArrayTypeSyntax.self) {
            // Array type.
            return types(for: arrayType.element)
        } else if let dictType = typeSyntax.as(DictionaryTypeSyntax.self) {
            // Dictionary type.
            return types(for: dictType.key).union(types(for: dictType.value))
        } else if let someType = typeSyntax.as(SomeOrAnyTypeSyntax.self) {
            // Some type.
            return types(for: someType.constraint)
        } else if let implicitUnwrappedOptionalType = typeSyntax.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            // Implicitly unwrapped optional type.
            return types(for: implicitUnwrappedOptionalType.wrappedType)
        } else if let compositionType = typeSyntax.as(CompositionTypeSyntax.self) {
            // Composition type.
            return compositionType.elements.flatMapSet { types(for: $0.type) }
        } else if let attributedType = typeSyntax.as(AttributedTypeSyntax.self) {
            // Attributed type.
            return types(for: attributedType.baseType)
        } else if let metatypeType = typeSyntax.as(MetatypeTypeSyntax.self) {
            // Metatype type.
            return types(for: metatypeType.baseType)
        } else if let inlineArrayType = typeSyntax.as(InlineArrayTypeSyntax.self) {
            // Inline array type, `[3 of T]`. The count may name a generic value parameter.
            return types(for: inlineArrayType.count).union(types(for: inlineArrayType.element))
        } else if let packExpansionType = typeSyntax.as(PackExpansionTypeSyntax.self) {
            // Pack expansion type, `repeat P<each T>`.
            return types(for: packExpansionType.repetitionPattern)
        } else if let packElementType = typeSyntax.as(PackElementTypeSyntax.self) {
            // Pack element type, `each T`.
            return types(for: packElementType.pack)
        } else if let namedOpaqueReturnType = typeSyntax.as(NamedOpaqueReturnTypeSyntax.self) {
            // Named opaque return type, `<T: P> Foo<T>`.
            return types(for: namedOpaqueReturnType.type)
                .union(types(in: Syntax(namedOpaqueReturnType.genericParameterClause)))
        }

        // Any other type node, including those added by future versions of SwiftSyntax, contributes the types among
        // its descendants.
        return types(in: Syntax(typeSyntax))
    }

    private func types(for argument: GenericArgumentSyntax) -> Set<TokenSyntax> {
        guard case let .type(argumentType) = argument.argument else { return [] }

        return types(for: argumentType)
    }

    /// The types written among the descendants of the node, which is not itself a type.
    private func types(in node: Syntax) -> Set<TokenSyntax> {
        node.children(viewMode: .sourceAccurate).flatMapSet { child in
            if let childType = child.as(TypeSyntax.self) {
                return types(for: childType)
            }

            return types(in: child)
        }
    }
}
