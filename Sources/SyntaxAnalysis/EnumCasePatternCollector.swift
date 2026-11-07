import SourceGraph
import SwiftSyntax

/// Collects the names written at pattern positions that may refer to enum cases, and the identifiers written inside
/// `#if` blocks.
///
/// The pattern positions are the patterns of `switch` case items, of `if`/`guard`/`while case` conditions, of
/// `for case` loops and of `catch` clauses. Inside a pattern, only the shapes that the compiler resolves as an enum
/// case pattern are collected: `.name`, `Type.name`, a call of either form whose arguments are sub-patterns, and
/// their tuples, optional patterns (`.name?`) and binding patterns (`let`/`var`). Any other expression in a pattern
/// (a literal, an operator, a closure, a function call that is not on a member) is matched with `~=` and may build a
/// value, so the names inside it are not collected.
///
/// The index store only holds the active clause of an `#if` block, so a construction written in another clause is not
/// indexed. Every identifier written in any clause is collected, active clause included.
public final class EnumCasePatternCollector: PeripherySyntaxNodeVisitor {
    public private(set) var sites: [Location: EnumCasePatternSite] = [:]
    public private(set) var conditionalNames: Set<String> = []

    private let file: SourceFile
    private let locationConverter: SourceLocationConverter

    public init(file: SourceFile, locationConverter: SourceLocationConverter) {
        self.file = file
        self.locationConverter = locationConverter
    }

    public func visit(_ node: SwitchCaseItemSyntax) {
        collect(pattern: node.pattern, enclosingCall: nil)
    }

    public func visit(_ node: MatchingPatternConditionSyntax) {
        collect(pattern: node.pattern, enclosingCall: nil)
    }

    public func visit(_ node: ForStmtSyntax) {
        if node.caseKeyword != nil {
            collect(pattern: node.pattern, enclosingCall: nil)
        }
    }

    public func visit(_ node: CatchItemSyntax) {
        if let pattern = node.pattern {
            collect(pattern: pattern, enclosingCall: nil)
        }
    }

    public func visit(_ node: IfConfigClauseSyntax) {
        if let elements = node.elements {
            for token in elements.tokens(viewMode: .sourceAccurate) {
                if case .identifier = token.tokenKind {
                    conditionalNames.insert(token.text.trimmingBackticks)
                }
            }
        }
    }

    // MARK: - Private

    private func collect(pattern: PatternSyntax, enclosingCall: Location?) {
        if let expressionPattern = pattern.as(ExpressionPatternSyntax.self) {
            collect(expression: expressionPattern.expression, enclosingCall: enclosingCall)
        } else if let bindingPattern = pattern.as(ValueBindingPatternSyntax.self) {
            collect(pattern: bindingPattern.pattern, enclosingCall: enclosingCall)
        } else if let tuplePattern = pattern.as(TuplePatternSyntax.self) {
            for element in tuplePattern.elements {
                collect(pattern: element.pattern, enclosingCall: enclosingCall)
            }
        }
    }

    private func collect(expression: ExprSyntax, enclosingCall: Location?) {
        if let member = caseMember(expression) {
            record(member, shape: .name, enclosingCall: enclosingCall)
        } else if let call = expression.as(FunctionCallExprSyntax.self),
                  call.trailingClosure == nil,
                  call.additionalTrailingClosures.isEmpty,
                  let callee = caseMember(call.calledExpression)
        {
            let calleeLocation = record(callee, shape: .call, enclosingCall: enclosingCall)
            for argument in call.arguments {
                collect(expression: argument.expression, enclosingCall: calleeLocation)
            }
        } else if let tuple = expression.as(TupleExprSyntax.self) {
            for element in tuple.elements {
                collect(expression: element.expression, enclosingCall: enclosingCall)
            }
        } else if let optional = expression.as(OptionalChainingExprSyntax.self) {
            collect(expression: optional.expression, enclosingCall: enclosingCall)
        } else if let patternExpression = expression.as(PatternExprSyntax.self) {
            collect(pattern: patternExpression.pattern, enclosingCall: enclosingCall)
        }
    }

    /// `.name` or `Base.name`, without argument labels (`.name(_:)` names a function value).
    private func caseMember(_ expression: ExprSyntax) -> MemberAccessExprSyntax? {
        guard let member = expression.as(MemberAccessExprSyntax.self),
              member.declName.argumentNames == nil
        else { return nil }

        return member
    }

    @discardableResult
    private func record(_ member: MemberAccessExprSyntax, shape: EnumCasePatternSite.Shape, enclosingCall: Location?) -> Location {
        let position = locationConverter.location(for: member.declName.baseName.positionAfterSkippingLeadingTrivia)
        let location = Location(file: file, line: position.line, column: position.column)
        sites[location] = EnumCasePatternSite(shape: shape, enclosingCall: enclosingCall)
        return location
    }
}

private extension String {
    var trimmingBackticks: String {
        guard hasPrefix("`"), hasSuffix("`"), count > 1 else { return self }

        return String(dropFirst().dropLast())
    }
}
