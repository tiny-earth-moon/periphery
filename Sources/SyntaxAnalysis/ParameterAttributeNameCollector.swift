import Foundation
import SwiftSyntax

/// Collects the names of the attributes written on function and closure parameters, e.g. `Clamped` in
/// `func apply(@Clamped(0 ... 5) level: Int)`.
///
/// A property wrapper applied to a parameter is initialized implicitly at each call site, a use that the index store
/// does not record against the wrapper's initializer.
public final class ParameterAttributeNameCollector: SyntaxVisitor {
    public private(set) var names: Set<String> = []

    public init() {
        super.init(viewMode: .sourceAccurate)
    }

    public static func collect(from syntax: SourceFileSyntax) -> Set<String> {
        let collector = ParameterAttributeNameCollector()
        collector.walk(syntax)
        return collector.names
    }

    override public func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        collect(node.attributes)
        return .visitChildren
    }

    override public func visit(_ node: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
        collect(node.attributes)
        return .visitChildren
    }

    // MARK: - Private

    private func collect(_ attributes: AttributeListSyntax) {
        for element in attributes {
            guard case let .attribute(attribute) = element else { continue }

            if let name = baseName(of: attribute.attributeName) {
                names.insert(name)
            }
        }
    }

    private func baseName(of type: TypeSyntax) -> String? {
        if let type = type.as(IdentifierTypeSyntax.self) {
            return type.name.text
        }

        if let type = type.as(MemberTypeSyntax.self) {
            return type.name.text
        }

        return nil
    }
}
