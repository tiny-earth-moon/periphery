import Foundation
import Shared
import SourceGraph
import SwiftSyntax

/// Collects the values passed to APIs that describe them through reflection: `print`, `debugPrint`, `dump`,
/// `String(describing:)`, `String(reflecting:)` and unlabeled string interpolation segments.
///
/// The index store cannot record these uses because the stored properties are read by the runtime, so each value is
/// recorded either by the token where the index store references its type, constructor or property, or by the type
/// name of the local variable or parameter that holds it.
public final class SynthesizedUseCollector: PeripherySyntaxVisitor {
    private static let printFunctionNames: Set = ["print", "debugPrint"]
    private static let describingLabels: Set = ["describing", "reflecting"]
    private static let maxLocalResolutionDepth = 4

    public private(set) var uses: Set<SynthesizedUse> = []

    private let sourceLocationBuilder: SourceLocationBuilder

    init(sourceLocationBuilder: SourceLocationBuilder) {
        self.sourceLocationBuilder = sourceLocationBuilder
    }

    public convenience init(sourceLocationBuilder: SourceLocationBuilder, swiftVersion _: SwiftVersion) {
        self.init(sourceLocationBuilder: sourceLocationBuilder)
    }

    public static func collect(
        from syntax: SourceFileSyntax,
        file: SourceFile,
        locationConverter: SourceLocationConverter
    ) -> Set<SynthesizedUse> {
        let builder = SourceLocationBuilder(file: file, locationConverter: locationConverter)
        let collector = SynthesizedUseCollector(sourceLocationBuilder: builder)
        collector.walk(syntax)
        return collector.uses
    }

    public func visit(_ node: FunctionCallExprSyntax) {
        guard let callee = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text else { return }

        if Self.printFunctionNames.contains(callee) {
            for argument in node.arguments where argument.label == nil {
                collect(argument.expression, kind: .description, depth: 0)
            }
        } else if callee == "dump", let argument = node.arguments.first, argument.label == nil {
            collect(argument.expression, kind: .dump, depth: 0)
        } else if callee == "String", node.arguments.count == 1, let argument = node.arguments.first,
                  let label = argument.label?.text, Self.describingLabels.contains(label)
        {
            collect(argument.expression, kind: .description, depth: 0)
        }
    }

    public func visit(_ node: ExpressionSegmentSyntax) {
        // Labeled segments such as `\(value, format: ...)` call a custom `appendInterpolation`.
        if node.expressions.count == 1, let element = node.expressions.first, element.label == nil {
            collect(element.expression, kind: .description, depth: 0)
        }
    }

    // MARK: - Private

    private func collect(_ expression: ExprSyntax, kind: SynthesizedUse.Kind, depth: Int) {
        let expression = unwrapped(expression)

        if let call = expression.as(FunctionCallExprSyntax.self) {
            if let token = call.calledExpression.calleeNameToken {
                insert(token, kind: kind)
            }
        } else if let reference = expression.as(DeclReferenceExprSyntax.self) {
            insert(reference.baseName, kind: kind)
            resolveLocal(named: reference.baseName.text, from: Syntax(reference), kind: kind, depth: depth)
        } else if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            insert(memberAccess.declName.baseName, kind: kind)
        }
    }

    private func unwrapped(_ expression: ExprSyntax) -> ExprSyntax {
        if let tuple = expression.as(TupleExprSyntax.self), tuple.elements.count == 1, let element = tuple.elements.first {
            return unwrapped(element.expression)
        }

        if let forceUnwrap = expression.as(ForceUnwrapExprSyntax.self) {
            return unwrapped(forceUnwrap.expression)
        }

        if let optionalChaining = expression.as(OptionalChainingExprSyntax.self) {
            return unwrapped(optionalChaining.expression)
        }

        if let tryExpression = expression.as(TryExprSyntax.self) {
            return unwrapped(tryExpression.expression)
        }

        if let awaitExpression = expression.as(AwaitExprSyntax.self) {
            return unwrapped(awaitExpression.expression)
        }

        return expression
    }

    /// Local variables and parameters are not in the index store, so their type is recovered from their declaration:
    /// its type annotation, or the expression that initializes it.
    private func resolveLocal(named name: String, from node: Syntax, kind: SynthesizedUse.Kind, depth: Int) {
        guard depth < Self.maxLocalResolutionDepth else { return }

        var child = node
        var current = node.parent

        while let ancestor = current {
            if let items = ancestor.as(CodeBlockItemListSyntax.self) {
                for item in items {
                    if item.position >= child.position {
                        break
                    }
                    guard let variable = item.item.as(VariableDeclSyntax.self) else { continue }

                    for binding in variable.bindings {
                        guard binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name else { continue }

                        if let type = binding.typeAnnotation?.type {
                            uses.insert(SynthesizedUse(kind: kind, typeName: type.trimmedDescription))
                        } else if let value = binding.initializer?.value {
                            collect(value, kind: kind, depth: depth + 1)
                        }
                        return
                    }
                }
            } else if let parameters = parameterClause(of: ancestor) {
                for parameter in parameters where (parameter.secondName ?? parameter.firstName).text == name {
                    uses.insert(SynthesizedUse(kind: kind, typeName: parameter.type.trimmedDescription))
                    return
                }
            }

            child = ancestor
            current = ancestor.parent
        }
    }

    private func parameterClause(of node: Syntax) -> FunctionParameterListSyntax? {
        if let function = node.as(FunctionDeclSyntax.self) {
            return function.signature.parameterClause.parameters
        }

        if let initializer = node.as(InitializerDeclSyntax.self) {
            return initializer.signature.parameterClause.parameters
        }

        return nil
    }

    private func insert(_ token: TokenSyntax, kind: SynthesizedUse.Kind) {
        let location = sourceLocationBuilder.location(at: token.positionAfterSkippingLeadingTrivia)
        uses.insert(SynthesizedUse(kind: kind, location: location))
    }
}
