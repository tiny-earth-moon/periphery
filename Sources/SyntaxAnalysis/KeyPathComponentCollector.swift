import Foundation
import SourceGraph
import SwiftSyntax

/// Collects the locations of the property components of key path expressions (`\.name`, `\Type.name`).
///
/// Since Swift 6.4 the index records a key path component as an implicit getter call plus a read of the property,
/// whatever the key path is later used for. A key path that is stored or passed on may be written through, so the
/// access kind of its components cannot be determined from the index. The exception are key paths used directly as
/// the argument of a `keyPath:` subscript, where the index records the access that is actually made.
public final class KeyPathComponentCollector: SyntaxVisitor {
    public private(set) var locations: Set<Location> = []

    private let sourceLocationBuilder: SourceLocationBuilder

    init(sourceLocationBuilder: SourceLocationBuilder) {
        self.sourceLocationBuilder = sourceLocationBuilder
        super.init(viewMode: .sourceAccurate)
    }

    public static func collect(
        from syntax: SourceFileSyntax,
        file: SourceFile,
        locationConverter: SourceLocationConverter
    ) -> Set<Location> {
        let builder = SourceLocationBuilder(file: file, locationConverter: locationConverter)
        let collector = KeyPathComponentCollector(sourceLocationBuilder: builder)
        collector.walk(syntax)
        return collector.locations
    }

    override public func visit(_ node: KeyPathExprSyntax) -> SyntaxVisitorContinueKind {
        guard !isDirectSubscriptArgument(node) else { return .visitChildren }

        for component in node.components {
            guard case let .property(property) = component.component else { continue }

            locations.insert(sourceLocationBuilder.location(at: property.declName.baseName.positionAfterSkippingLeadingTrivia))
        }

        return .visitChildren
    }

    // MARK: - Private

    private func isDirectSubscriptArgument(_ node: KeyPathExprSyntax) -> Bool {
        guard let argument = node.parent?.as(LabeledExprSyntax.self),
              argument.label?.text == "keyPath",
              argument.expression.as(KeyPathExprSyntax.self) == node,
              let call = argument.parent?.parent?.as(SubscriptCallExprSyntax.self)
        else { return false }

        return call.arguments.contains(argument)
    }
}
