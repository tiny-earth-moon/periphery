import Foundation
import SwiftIfConfig
import SwiftSyntax

/// Collects the identifiers written inside `#if` blocks conditioned on the target platform
/// (`os()`, `targetEnvironment()`, `arch()`, `canImport()`).
///
/// The index store only contains the code of the compilation condition that was built, so references
/// made from the inactive branches of these blocks are invisible to the indexer. Syntax trees contain
/// every branch, which allows us to know which names are possibly referenced from another platform.
///
/// When the build configurations of the indexed units are known, the clauses that one of them compiled are skipped:
/// their references are already in the index store. A block is only narrowed this way when every condition is made
/// of `os()`, `arch()` and `targetEnvironment()` checks joined by `!`, `&&` and `||`, when it is not nested in another
/// `#if` block, and when every configuration evaluates it without a diagnostic. Otherwise the whole block is collected.
///
/// With `narrowsNestedBlocks`, a block nested in other `#if` blocks is narrowed too, when every enclosing block can be
/// narrowed: a configuration compiles one of its clauses when it also compiles every enclosing clause. The clauses no
/// configuration compiles are collected exactly as without it.
public final class PlatformConditionalNameCollector: PeripherySyntaxNodeVisitor {
    private static let platformConditions: Set<String> = ["os", "targetEnvironment", "arch", "canImport"]

    private static let evaluableConditions: Set<String> = ["os", "arch", "targetEnvironment"]

    /// A line that names an identifier inside a platform conditional clause, and the clause's condition.
    public struct Site: Hashable {
        public let line: Int
        public let condition: String
    }

    public private(set) var names: Set<String> = []
    /// The sites of each name, only collected when a location converter is given (for `--explain`).
    public private(set) var sites: [String: [Site]] = [:]

    private let configurations: [PlatformBuildConfiguration]
    private let narrowsNestedBlocks: Bool
    private let locationConverter: SourceLocationConverter?
    /// The block whose clauses were all collected: the blocks it contains are not visited.
    private var collectedBlock: SyntaxIdentifier?

    /// - Parameter configurations: the configurations the file was compiled for. When empty, every clause of every
    ///   platform conditional block is collected.
    /// - Parameter narrowsNestedBlocks: whether the blocks nested in another `#if` block are narrowed too, instead of
    ///   being collected whole.
    /// - Parameter locationConverter: when given, the line and condition of each name are collected too.
    public init(
        configurations: [PlatformBuildConfiguration] = [],
        narrowsNestedBlocks: Bool = false,
        locationConverter: SourceLocationConverter? = nil
    ) {
        self.configurations = configurations
        self.narrowsNestedBlocks = narrowsNestedBlocks
        self.locationConverter = locationConverter
    }

    public static func collect(
        from syntax: SourceFileSyntax,
        configurations: [PlatformBuildConfiguration] = [],
        narrowsNestedBlocks: Bool = false
    ) -> Set<String> {
        let collector = PlatformConditionalNameCollector(configurations: configurations, narrowsNestedBlocks: narrowsNestedBlocks)
        collector.walk(syntax)
        return collector.names
    }

    public func visit(_ node: IfConfigDeclSyntax) {
        guard collectedBlock == nil, node.clauses.contains(where: { isPlatformCondition($0.condition) }) else { return }

        if let uncompiledClauses = uncompiledClauses(of: node) {
            uncompiledClauses.forEach(collectNames(in:))
            // Blocks nested in a compiled clause are visited: collected whole as they are nested, or narrowed with
            // `narrowsNestedBlocks`.
            return
        }

        // The `#else` clause has no condition of its own, so the whole block is collected.
        node.clauses.forEach(collectNames(in:))
        collectedBlock = node.id
    }

    public func visitPost(_ node: IfConfigDeclSyntax) {
        if node.id == collectedBlock {
            collectedBlock = nil
        }
    }

    // MARK: - Private

    private func collectNames(in clause: IfConfigClauseSyntax) {
        guard let elements = clause.elements else { return }

        for token in elements.tokens(viewMode: .sourceAccurate) {
            if case .identifier = token.tokenKind, isReference(token) {
                let name = token.identifier?.name ?? token.text
                names.insert(name)

                if let locationConverter {
                    let condition = clause.condition.map { "\(clause.poundKeyword.text) \($0.trimmedDescription)" } ?? clause.poundKeyword.text
                    let line = token.startLocation(converter: locationConverter).line
                    sites[name, default: []].append(Site(line: line, condition: condition))
                }
            }
        }
    }

    /// Returns the clauses that none of the configurations compiled, or `nil` when they cannot be known with
    /// certainty.
    private func uncompiledClauses(of node: IfConfigDeclSyntax) -> [IfConfigClauseSyntax]? {
        let enclosingClauses = enclosingClauses(of: node)

        guard !configurations.isEmpty,
              enclosingClauses.isEmpty || narrowsNestedBlocks,
              isEvaluable(node),
              enclosingClauses.allSatisfy({ isEvaluable($0.block) })
        else { return nil }

        var compiledClauses: Set<SyntaxIdentifier> = []

        for configuration in configurations {
            guard let clause = activeClause(of: node, in: configuration) else { return nil }

            var compilesEnclosingClauses = true
            for (block, enclosingClause) in enclosingClauses {
                guard let activeClause = activeClause(of: block, in: configuration) else { return nil }

                if activeClause?.id != enclosingClause.id {
                    compilesEnclosingClauses = false
                }
            }

            if compilesEnclosingClauses, let clause {
                compiledClauses.insert(clause.id)
            }
        }

        return node.clauses.filter { !compiledClauses.contains($0.id) }
    }

    /// The clause the configuration compiles, `.some(nil)` when it compiles none, or `nil` when it cannot be known.
    private func activeClause(of node: IfConfigDeclSyntax, in configuration: PlatformBuildConfiguration) -> IfConfigClauseSyntax?? {
        let (clause, diagnostics) = node.activeClause(in: configuration)
        guard diagnostics.isEmpty else { return nil }

        return .some(clause)
    }

    private func isEvaluable(_ node: IfConfigDeclSyntax) -> Bool {
        node.clauses.allSatisfy { $0.condition.map(isEvaluable) ?? true }
    }

    /// The `#if` blocks the node is nested in, from the innermost, with the clause of each that contains it.
    private func enclosingClauses(of node: IfConfigDeclSyntax) -> [(block: IfConfigDeclSyntax, clause: IfConfigClauseSyntax)] {
        var result: [(block: IfConfigDeclSyntax, clause: IfConfigClauseSyntax)] = []
        var parent = node.parent

        while let current = parent {
            if let clause = current.as(IfConfigClauseSyntax.self), let block = clause.parent?.parent?.as(IfConfigDeclSyntax.self) {
                result.append((block, clause))
            }
            parent = current.parent
        }

        return result
    }

    /// Returns `true` when the condition only combines `os()`, `arch()` and `targetEnvironment()` checks with `!`,
    /// `&&`, `||` and parentheses.
    private func isEvaluable(_ condition: ExprSyntax) -> Bool {
        if let tuple = condition.as(TupleExprSyntax.self) {
            guard tuple.elements.count == 1, let element = tuple.elements.first, element.label == nil else {
                return false
            }

            return isEvaluable(element.expression)
        }

        if let prefix = condition.as(PrefixOperatorExprSyntax.self) {
            return prefix.operator.text == "!" && isEvaluable(prefix.expression)
        }

        if let sequence = condition.as(SequenceExprSyntax.self) {
            return sequence.elements.enumerated().allSatisfy { index, element in
                if index.isMultiple(of: 2) {
                    return isEvaluable(element)
                }

                guard let binaryOperator = element.as(BinaryOperatorExprSyntax.self) else { return false }

                return ["&&", "||"].contains(binaryOperator.operator.text)
            }
        }

        if let call = condition.as(FunctionCallExprSyntax.self) {
            guard let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
                  callee.argumentNames == nil,
                  Self.evaluableConditions.contains(callee.baseName.text),
                  call.trailingClosure == nil,
                  call.additionalTrailingClosures.isEmpty,
                  call.arguments.count == 1,
                  let argument = call.arguments.first,
                  argument.label == nil,
                  let name = argument.expression.as(DeclReferenceExprSyntax.self)
            else { return false }

            return name.argumentNames == nil
        }

        return false
    }

    /// Returns `true` when the token is the name in a `DeclReferenceExprSyntax`, `IdentifierTypeSyntax`,
    /// `MemberTypeSyntax`, `MacroExpansionExprSyntax` or `MacroExpansionDeclSyntax`.
    /// Declaration names, parameter names, argument labels and the type extended by an `extension` do not refer to a
    /// declaration: writing them in a conditional block must not retain it.
    private func isReference(_ token: TokenSyntax) -> Bool {
        guard let parent = token.parent else { return false }

        if let extensionDeclaration = parent.parent?.as(ExtensionDeclSyntax.self),
           extensionDeclaration.extendedType.id == parent.id
        {
            return false
        }

        return parent.is(DeclReferenceExprSyntax.self)
            || parent.is(IdentifierTypeSyntax.self)
            || parent.is(MemberTypeSyntax.self)
            || parent.is(MacroExpansionExprSyntax.self)
            || parent.is(MacroExpansionDeclSyntax.self)
    }

    private func isPlatformCondition(_ condition: ExprSyntax?) -> Bool {
        guard let condition else { return false }

        return condition.tokens(viewMode: .sourceAccurate).contains {
            if case .identifier = $0.tokenKind {
                Self.platformConditions.contains($0.text)
            } else {
                false
            }
        }
    }
}
