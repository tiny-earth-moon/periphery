import Foundation
import SourceGraph
import SwiftSyntax

/// Collects the Swift expressions that name a Metal function: the `name:` argument of `makeFunction(name:)` and its
/// variants, and of `MTLFunctionStitchingFunctionNode(name:)`, and the value assigned to a `name` property.
///
/// Only an assignment to `MTLFunctionDescriptor.name` names a Metal function, which the indexer confirms from the
/// index store at the position of the `name` token.
public final class MetalFunctionNameCollector: SyntaxVisitor {
    public struct Candidate: Hashable {
        public let reference: MetalFunctionNameReference
        /// The position of the `name` token of an assignment, `nil` for a call, which needs no confirmation.
        public let propertyLocation: Location?
    }

    private static let callNames: Set = ["makeFunction", "MTLFunctionStitchingFunctionNode"]

    public private(set) var candidates: [Candidate] = []

    private let sourceLocationBuilder: SourceLocationBuilder

    init(sourceLocationBuilder: SourceLocationBuilder) {
        self.sourceLocationBuilder = sourceLocationBuilder
        super.init(viewMode: .sourceAccurate)
    }

    public static func collect(
        from syntax: SourceFileSyntax,
        file: SourceFile,
        locationConverter: SourceLocationConverter
    ) -> [Candidate] {
        let builder = SourceLocationBuilder(file: file, locationConverter: locationConverter)
        let collector = MetalFunctionNameCollector(sourceLocationBuilder: builder)
        collector.walk(syntax)
        return collector.candidates
    }

    override public func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let calleeName: String? = if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self) {
            memberAccess.declName.baseName.text
        } else if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            reference.baseName.text
        } else {
            nil
        }

        if let calleeName, Self.callNames.contains(calleeName),
           let argument = node.arguments.first, argument.label?.text == "name"
        {
            candidates.append(Candidate(reference: reference(to: argument.expression), propertyLocation: nil))
        }

        return .visitChildren
    }

    override public func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)

        for (index, element) in elements.enumerated() where element.is(AssignmentExprSyntax.self) {
            guard index > 0, index + 1 < elements.count else { continue }

            collectAssignment(to: elements[index - 1], value: elements[index + 1])
        }

        return .visitChildren
    }

    override public func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if node.operator.is(AssignmentExprSyntax.self) {
            collectAssignment(to: node.leftOperand, value: node.rightOperand)
        }

        return .visitChildren
    }

    // MARK: - Private

    private func collectAssignment(to target: ExprSyntax, value: ExprSyntax) {
        guard let memberAccess = target.as(MemberAccessExprSyntax.self),
              memberAccess.base != nil,
              memberAccess.declName.baseName.text == "name"
        else { return }

        let propertyLocation = sourceLocationBuilder.location(at: memberAccess.declName.baseName.positionAfterSkippingLeadingTrivia)
        candidates.append(Candidate(reference: reference(to: value), propertyLocation: propertyLocation))
    }

    private func reference(to expression: ExprSyntax) -> MetalFunctionNameReference {
        let location = sourceLocationBuilder.location(at: expression.positionAfterSkippingLeadingTrivia)
        let name = expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
        return MetalFunctionNameReference(name: name, location: location)
    }
}
