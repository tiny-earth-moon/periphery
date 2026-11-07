import Shared
import SourceGraph
import SwiftSyntax

/// Collects extensions that declare neither a member nor a conformance, e.g. `extension Foo {}`.
///
/// The index store has no record of such extensions, so they can only be found in the syntax tree.
public final class EmptyExtensionSyntaxVisitor: PeripherySyntaxVisitor {
    public struct Result {
        public let extendedTypeName: String
        public let location: Location
        public let commentCommands: [CommentCommand]
        public let range: DeclarationRange
    }

    public private(set) var results: [Result] = []

    private let sourceLocationBuilder: SourceLocationBuilder

    public init(sourceLocationBuilder: SourceLocationBuilder, swiftVersion _: SwiftVersion) {
        self.sourceLocationBuilder = sourceLocationBuilder
    }

    public func visit(_ node: ExtensionDeclSyntax) {
        guard node.inheritanceClause == nil,
              hasOnlyAvailabilityAttributes(node),
              isEmpty(node.memberBlock.members)
        else { return }

        let result = Result(
            extendedTypeName: node.extendedType.trimmedDescription,
            location: sourceLocationBuilder.location(at: node.extendedType.positionAfterSkippingLeadingTrivia),
            commentCommands: CommentCommand.parseCommands(in: node.leadingTrivia),
            range: sourceLocationBuilder.declarationRange(of: node, attributes: node.attributes)
        )
        results.append(result)
    }

    // MARK: - Private

    /// Attached macros can add members or conformances to an extension, only availability attributes cannot.
    private func hasOnlyAvailabilityAttributes(_ node: ExtensionDeclSyntax) -> Bool {
        node.attributes.allSatisfy { element in
            guard case let .attribute(attribute) = element else { return false }

            return attribute.attributeName.trimmedDescription == "available"
        }
    }

    /// Members are empty when the only declarations are `#if` blocks whose clauses are all empty.
    private func isEmpty(_ members: MemberBlockItemListSyntax) -> Bool {
        members.allSatisfy { member in
            guard let ifConfig = member.decl.as(IfConfigDeclSyntax.self) else { return false }

            return ifConfig.clauses.allSatisfy { clause in
                switch clause.elements {
                case .none:
                    true
                case let .decls(decls):
                    isEmpty(decls)
                default:
                    false
                }
            }
        }
    }
}
