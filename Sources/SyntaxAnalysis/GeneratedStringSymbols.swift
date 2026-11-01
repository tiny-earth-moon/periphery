import SwiftParser
import SwiftSyntax

/// Reads the String Catalog symbols Xcode generates in `GeneratedStringSymbols_<Table>.swift`
/// (`STRING_CATALOG_GENERATE_SYMBOLS`), e.g.
/// `static var settingsTitle: LocalizedStringResource { LocalizedStringResource("settings.title", table: ...) }`.
///
/// Based on agoodkind/periphery@783b5f8 by Alex Goodkind.
public final class GeneratedStringSymbols: SyntaxVisitor {
    /// The catalogue key of each generated symbol, by the line of the symbol's name, where the index store records its
    /// definition.
    public private(set) var keysByLine: [Int: String] = [:]

    private let converter: SourceLocationConverter

    private init(tree: SourceFileSyntax) {
        converter = SourceLocationConverter(fileName: "", tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    public static func keys(in source: String) -> [Int: String] {
        let tree = Parser.parse(source: source)
        let visitor = GeneratedStringSymbols(tree: tree)
        visitor.walk(tree)
        return visitor.keysByLine
    }

    override public func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.modifiers.contains(where: { $0.name.text == "static" }) else { return .skipChildren }

        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let accessorBlock = binding.accessorBlock,
                  let key = Self.key(in: accessorBlock)
            else { continue }

            keysByLine[converter.location(for: identifier.identifier.positionAfterSkippingLeadingTrivia).line] = key
        }

        return .skipChildren
    }

    override public func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.modifiers.contains(where: { $0.name.text == "static" }),
              let body = node.body,
              let key = Self.key(in: body)
        else { return .skipChildren }

        keysByLine[converter.location(for: node.name.positionAfterSkippingLeadingTrivia).line] = key
        return .skipChildren
    }

    // MARK: - Private

    /// The key of the single `LocalizedStringResource("key", ...)` the symbol returns.
    private static func key(in node: some SyntaxProtocol) -> String? {
        let collector = ResourceKeyCollector(viewMode: .sourceAccurate)
        collector.walk(node)
        guard collector.keys.count == 1 else { return nil }

        return collector.keys.first
    }
}

private final class ResourceKeyCollector: SyntaxVisitor {
    var keys: Set<String> = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "LocalizedStringResource",
              let argument = node.arguments.first,
              argument.label == nil,
              let key = argument.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
        else { return .visitChildren }

        keys.insert(key)
        return .skipChildren
    }
}
