import Foundation
import Shared
import SwiftSyntax

/// Collects string keys used for localization in Swift source files.
///
/// Keys are collected in two ways:
/// - `usedStringKeys` holds keys that are known to be used from syntax alone:
///   - `NSLocalizedString("key", ...)`, `String(localized: "key", ...)`, `LocalizedStringKey("key")`,
///     `LocalizedStringResource("key", ...)`, `Text("key")` and `Bundle.localizedString(forKey: "key", ...)`.
///   - AppIntents `@Parameter(title:)` / `@Property(title:)` attribute arguments.
///   - Literals assigned to, returned from, or used as the default value of a declaration whose type is a
///     localized type (e.g. `let title: LocalizedStringResource = "key"`).
///   - Literals passed to a call whose callee cannot be located syntactically (conservatively retained).
/// - `callSites` holds the remaining calls that receive string literals. Whether those literals are keys depends on
///   the type of the receiving parameter, which is resolved from the index store by the indexer.
public final class LocalizedStringSyntaxVisitor: PeripherySyntaxVisitor {
    /// Type names whose values are created from a localization key when initialized from a string literal.
    public static let localizedTypeNames = [
        "LocalizedStringKey",
        "LocalizedStringResource",
        "LocalizationValue",
        "DisplayRepresentation",
        "IntentDescription",
        "IntentDialog",
        "ParameterSummaryString",
        "AppShortcutPhrase",
    ]

    /// AppIntents property wrappers whose arguments take a localization key as a string literal.
    private static let localizedAttributeNames: Set = ["Parameter", "Property"]
    private static let localizedAttributeLabels: Set = [
        "title", "description", "requestValueDialog", "requestConfirmationDialog", "requestDisambiguationDialog",
    ]

    public private(set) var usedStringKeys: Set<String> = []
    public private(set) var callSites: [LocalizedStringCallSite] = []

    private let sourceLocationBuilder: SourceLocationBuilder

    public init(sourceLocationBuilder: SourceLocationBuilder, swiftVersion _: SwiftVersion) {
        self.sourceLocationBuilder = sourceLocationBuilder
    }

    public static func isLocalizedType(_ typeName: String) -> Bool {
        localizedTypeNames.contains { typeName.contains($0) }
    }

    public func visit(_ node: FunctionCallExprSyntax) {
        collectKnownCallKeys(node)
        collectCallSite(node)
    }

    /// `@Parameter(title: "key")` is an attribute rather than a call, so it is invisible to call site resolution.
    public func visit(_ node: AttributeSyntax) {
        guard let name = node.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
              Self.localizedAttributeNames.contains(name),
              case let .argumentList(arguments) = node.arguments
        else { return }

        for argument in arguments {
            guard let label = argument.label?.text, Self.localizedAttributeLabels.contains(label) else { continue }

            insertLiteral(argument.expression)
        }
    }

    public func visit(_ node: VariableDeclSyntax) {
        for binding in node.bindings {
            guard let type = binding.typeAnnotation?.type, Self.isLocalizedType(type.trimmedDescription) else { continue }

            if let value = binding.initializer?.value {
                usedStringKeys.formUnion(literalKeys(in: value, ofType: type))
            }

            if let accessorBlock = binding.accessorBlock {
                usedStringKeys.formUnion(ReturnedLiteralCollector.collect(in: accessorBlock))
            }
        }
    }

    public func visit(_ node: FunctionDeclSyntax) {
        collectDefaultValueKeys(node.signature.parameterClause)

        if let returnType = node.signature.returnClause?.type,
           Self.isLocalizedType(returnType.trimmedDescription),
           let body = node.body
        {
            usedStringKeys.formUnion(ReturnedLiteralCollector.collect(in: body))
        }
    }

    public func visit(_ node: InitializerDeclSyntax) {
        collectDefaultValueKeys(node.signature.parameterClause)
    }

    public func visit(_ node: SubscriptDeclSyntax) {
        collectDefaultValueKeys(node.parameterClause)

        if Self.isLocalizedType(node.returnClause.type.trimmedDescription), let accessorBlock = node.accessorBlock {
            usedStringKeys.formUnion(ReturnedLiteralCollector.collect(in: accessorBlock))
        }
    }

    // MARK: - Private

    private func collectDefaultValueKeys(_ clause: FunctionParameterClauseSyntax) {
        for parameter in clause.parameters {
            guard Self.isLocalizedType(parameter.type.trimmedDescription),
                  let value = parameter.defaultValue?.value
            else { continue }

            usedStringKeys.formUnion(literalKeys(in: value, ofType: parameter.type))
        }
    }

    /// String literals of an expression that initialize a value of a localized type, matching tuple, array and
    /// dictionary literals against the corresponding element types of `type` (e.g. only the first element of
    /// `("key", "symbol")` for `(LocalizedStringKey, String)`).
    private func literalKeys(in expression: ExprSyntax, ofType type: TypeSyntax) -> [String] {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return literalKeys(in: expression, ofType: optional.wrappedType)
        }

        if let optional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return literalKeys(in: expression, ofType: optional.wrappedType)
        }

        if let tupleType = type.as(TupleTypeSyntax.self) {
            if tupleType.elements.count == 1, let element = tupleType.elements.first {
                return literalKeys(in: expression, ofType: element.type)
            }

            if let tuple = expression.as(TupleExprSyntax.self), tuple.elements.count == tupleType.elements.count {
                return zip(tuple.elements, tupleType.elements).flatMap { literalKeys(in: $0.expression, ofType: $1.type) }
            }
        }

        if let arrayType = type.as(ArrayTypeSyntax.self), let array = expression.as(ArrayExprSyntax.self) {
            return array.elements.flatMap { literalKeys(in: $0.expression, ofType: arrayType.element) }
        }

        if let dictionaryType = type.as(DictionaryTypeSyntax.self),
           let dictionary = expression.as(DictionaryExprSyntax.self)
        {
            guard case let .elements(elements) = dictionary.content else { return [] }

            return elements.flatMap {
                literalKeys(in: $0.key, ofType: dictionaryType.key) + literalKeys(in: $0.value, ofType: dictionaryType.value)
            }
        }

        guard Self.isLocalizedType(type.trimmedDescription) else { return [] }

        return literalKeys(in: expression)
    }

    private func collectCallSite(_ node: FunctionCallExprSyntax) {
        let arguments = node.arguments.map { argument in
            LocalizedStringCallSite.Argument(label: argument.label?.text, keys: literalKeys(in: argument.expression))
        }

        guard arguments.contains(where: { !$0.keys.isEmpty }) else { return }
        guard let calleeToken = calleeNameToken(of: node.calledExpression) else {
            // The callee cannot be resolved, conservatively assume the literals are keys.
            usedStringKeys.formUnion(arguments.flatMap(\.keys))
            return
        }

        let location = sourceLocationBuilder.location(at: calleeToken.positionAfterSkippingLeadingTrivia)
        callSites.append(LocalizedStringCallSite(line: location.line, column: location.column, arguments: arguments))
    }

    private func calleeNameToken(of expression: ExprSyntax) -> TokenSyntax? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName
        }

        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName
        }

        if let specialization = expression.as(GenericSpecializationExprSyntax.self) {
            return calleeNameToken(of: specialization.expression)
        }

        return nil
    }

    /// Detects well-known localization APIs by name. These are retained regardless of index store resolution.
    private func collectKnownCallKeys(_ node: FunctionCallExprSyntax) {
        let calledExpression = node.calledExpression

        if let identifier = calledExpression.as(DeclReferenceExprSyntax.self) {
            switch identifier.baseName.text {
            case "NSLocalizedString", "LocalizedStringKey", "LocalizedStringResource", "Text":
                // The first unlabeled string argument is the key.
                if let firstArg = node.arguments.first, firstArg.label == nil {
                    insertLiteral(firstArg.expression)
                }
            case "String":
                if let localizedArg = node.arguments.first(where: { $0.label?.text == "localized" }) {
                    insertLiteral(localizedArg.expression)
                }
            default:
                break
            }
            return
        }

        // Handle member access like Bundle.main.localizedString(forKey: "key", ...)
        if let memberAccess = calledExpression.as(MemberAccessExprSyntax.self),
           memberAccess.declName.baseName.text == "localizedString",
           let forKeyArg = node.arguments.first(where: { $0.label?.text == "forKey" })
        {
            insertLiteral(forKeyArg.expression)
        }
    }

    private func insertLiteral(_ expression: ExprSyntax) {
        usedStringKeys.formUnion(literalKeys(in: expression))
    }

    /// The catalogue key of a string literal. An interpolated literal maps to the format key Foundation derives
    /// from it: each interpolation becomes a format specifier (`%lld` for an integer literal, `%lf` for a
    /// floating-point literal, the `specifier:` argument when given, `%@` otherwise) and a literal `%` is escaped
    /// as `%%`. Since the type of an interpolated value is unknown, catalogue keys are matched against interpolated
    /// keys with each specifier treated as a wildcard.
    static func localizationKey(of literal: StringLiteralExprSyntax) -> String? {
        if let value = literal.representedLiteralValue {
            return value
        }

        var key = ""

        for segment in literal.segments {
            switch segment {
            case let .stringSegment(stringSegment):
                let segmentLiteral = literal.with(\.segments, [.stringSegment(stringSegment)])
                guard let value = segmentLiteral.representedLiteralValue else { return nil }

                key += value.replacingOccurrences(of: "%", with: "%%")
            case let .expressionSegment(expressionSegment):
                key += formatSpecifier(for: expressionSegment)
            }
        }

        return key
    }

    private static func formatSpecifier(for segment: ExpressionSegmentSyntax) -> String {
        if let specifier = segment.expressions.first(where: { $0.label?.text == "specifier" }),
           let literal = specifier.expression.as(StringLiteralExprSyntax.self),
           let value = literal.representedLiteralValue
        {
            return value
        }

        guard segment.expressions.count == 1, let expression = segment.expressions.first?.expression else { return "%@" }

        var value = expression
        if let prefix = value.as(PrefixOperatorExprSyntax.self) {
            value = prefix.expression
        }

        if value.is(IntegerLiteralExprSyntax.self) {
            return "%lld"
        }

        if value.is(FloatLiteralExprSyntax.self) {
            return "%lf"
        }

        return "%@"
    }

    /// String literals that an expression may evaluate to, looking through parentheses, ternaries, tuple, array and
    /// dictionary literals, `if`/`switch` expressions and closure bodies. Interpolated literals are normalized to
    /// their format key.
    private func literalKeys(in expression: ExprSyntax) -> [String] {
        if let stringLiteral = expression.as(StringLiteralExprSyntax.self) {
            return Self.localizationKey(of: stringLiteral).map { [$0] } ?? []
        }

        if let tuple = expression.as(TupleExprSyntax.self) {
            // A parenthesized expression, or a tuple whose element types are given by the receiving declaration.
            return tuple.elements.flatMap { literalKeys(in: $0.expression) }
        }

        if let ternary = expression.as(TernaryExprSyntax.self) {
            return literalKeys(in: ternary.thenExpression) + literalKeys(in: ternary.elseExpression)
        }

        if let unresolvedTernary = expression.as(UnresolvedTernaryExprSyntax.self) {
            return literalKeys(in: unresolvedTernary.thenExpression)
        }

        if let sequence = expression.as(SequenceExprSyntax.self), sequence.elements.contains(where: { $0.is(UnresolvedTernaryExprSyntax.self) }) {
            // An unfolded ternary: `condition ? "a" : "b"`. Only the branches can be keys.
            let elements = Array(sequence.elements)
            guard let ternaryIndex = elements.firstIndex(where: { $0.is(UnresolvedTernaryExprSyntax.self) }) else { return [] }

            return elements[ternaryIndex...].flatMap { literalKeys(in: $0) }
        }

        if let array = expression.as(ArrayExprSyntax.self) {
            return array.elements.flatMap { literalKeys(in: $0.expression) }
        }

        if let dictionary = expression.as(DictionaryExprSyntax.self),
           case let .elements(elements) = dictionary.content
        {
            return elements.flatMap { literalKeys(in: $0.key) + literalKeys(in: $0.value) }
        }

        // Expressions whose value is the literal returned from a body: `if`/`switch` expressions, closures and
        // immediately applied closures.
        if expression.is(IfExprSyntax.self) || expression.is(SwitchExprSyntax.self) {
            return ReturnedLiteralCollector.collect(in: expression).sorted()
        }

        if let closure = expression.as(ClosureExprSyntax.self) {
            return ReturnedLiteralCollector.collect(in: closure.statements).sorted()
        }

        if let call = expression.as(FunctionCallExprSyntax.self), call.arguments.isEmpty,
           let closure = call.calledExpression.as(ClosureExprSyntax.self)
        {
            return ReturnedLiteralCollector.collect(in: closure.statements).sorted()
        }

        return []
    }
}

/// Collects the string literals a body may return, ignoring literals passed to calls, used in conditions or patterns,
/// or nested in closures and local declarations.
private final class ReturnedLiteralCollector: SyntaxVisitor {
    private var keys: Set<String> = []

    static func collect(in node: some SyntaxProtocol) -> Set<String> {
        let collector = ReturnedLiteralCollector(viewMode: .sourceAccurate)
        collector.walk(node)
        return collector.keys
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        if let key = LocalizedStringSyntaxVisitor.localizationKey(of: node) {
            keys.insert(key)
        }
        return .skipChildren
    }

    override func visit(_: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: SubscriptCallExprSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: ConditionElementListSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: SwitchCaseLabelSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}
