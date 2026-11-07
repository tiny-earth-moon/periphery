import SwiftParser
import SwiftSyntax

/// The declarations of a Swift file with the lines they cover, keyed by the positions the index store reports for
/// them: the name of a type, function, property or enum case, the `init`, `deinit` or `subscript` keyword, the
/// extended type of an extension, and the start of an import.
struct SourceFileDeclarations {
    struct Position: Hashable {
        let line: Int
        let column: Int
    }

    /// A declaration, removed only when each of its elements is reported: `let a = 1, b = 2` and `case a, b` have
    /// one element per name, every other declaration has one.
    struct Span {
        let lines: ClosedRange<Int>
        let elementCount: Int
    }

    let lineCount: Int
    let spans: [Span]
    /// The span and element index of each position.
    let elementsByPosition: [Position: (span: Int, element: Int)]
    /// The spans of the top-level declarations, imports excepted.
    let topLevelSpans: [Int]
    /// Whether the top level holds code that is neither an import nor a declaration known to the index, e.g. a
    /// statement of `main.swift`, so that the file cannot be removed whole.
    let hasOtherTopLevelCode: Bool

    init(source: String) {
        let tree = Parser.parse(source: source)
        var collector = Collector(converter: SourceLocationConverter(fileName: "", tree: tree))
        collector.walk(Syntax(tree))

        var topLevelSpans: [Int] = []
        var hasOtherTopLevelCode = false
        Self.collectTopLevel(tree.statements, spanIndexes: collector.spanIndexes, into: &topLevelSpans, other: &hasOtherTopLevelCode)

        lineCount = Self.lineCount(of: source)
        spans = collector.spans
        elementsByPosition = collector.elementsByPosition
        self.topLevelSpans = topLevelSpans
        self.hasOtherTopLevelCode = hasOtherTopLevelCode
    }

    // MARK: - Private

    private static func lineCount(of source: String) -> Int {
        let newlines = source.utf8.count(where: { $0 == UInt8(ascii: "\n") })
        return source.utf8.last.map { $0 == UInt8(ascii: "\n") ? newlines : newlines + 1 } ?? 0
    }

    private static func collectTopLevel(_ items: CodeBlockItemListSyntax, spanIndexes: [SyntaxIdentifier: Int], into spans: inout [Int], other: inout Bool) {
        for item in items {
            guard case let .decl(decl) = item.item else {
                other = true
                continue
            }

            if decl.is(ImportDeclSyntax.self) {
                continue
            }

            if let ifConfig = decl.as(IfConfigDeclSyntax.self) {
                for clause in ifConfig.clauses {
                    switch clause.elements {
                    case let .statements(statements):
                        collectTopLevel(statements, spanIndexes: spanIndexes, into: &spans, other: &other)
                    case .none:
                        break
                    default:
                        other = true
                    }
                }
                continue
            }

            if let index = spanIndexes[decl.id] {
                spans.append(index)
            } else {
                other = true
            }
        }
    }

    private struct Collector {
        let converter: SourceLocationConverter
        private(set) var spans: [Span] = []
        private(set) var spanIndexes: [SyntaxIdentifier: Int] = [:]
        private(set) var elementsByPosition: [Position: (span: Int, element: Int)] = [:]

        init(converter: SourceLocationConverter) {
            self.converter = converter
        }

        mutating func walk(_ node: Syntax) {
            if let decl = node.as(DeclSyntax.self) {
                record(decl)
            }

            for child in node.children(viewMode: .sourceAccurate) {
                walk(child)
            }
        }

        private mutating func record(_ decl: DeclSyntax) {
            let elements = elementPositions(of: decl)
            guard !elements.isEmpty else { return }

            let index = spans.count
            spans.append(Span(lines: startLine(of: decl) ... line(at: decl.endPositionBeforeTrailingTrivia), elementCount: elements.count))
            spanIndexes[decl.id] = index

            for (element, positions) in elements.enumerated() {
                for position in positions {
                    elementsByPosition[position] = (index, element)
                }
            }
        }

        /// The positions of each element of the declaration, as the index store reports them. An extension has a
        /// single element, reported at one of the tokens of its extended type, e.g. `Bar` in `extension Foo.Bar`.
        private func elementPositions(of decl: DeclSyntax) -> [[Position]] {
            if let ext = decl.as(ExtensionDeclSyntax.self) {
                return [ext.extendedType.tokens(viewMode: .sourceAccurate).map { position(at: $0.positionAfterSkippingLeadingTrivia) }]
            }

            if decl.is(ImportDeclSyntax.self) {
                return [[position(at: decl.positionAfterSkippingLeadingTrivia)]]
            }

            let tokens: [TokenSyntax] = switch decl.as(DeclSyntaxEnum.self) {
            case let .classDecl(decl): [decl.name]
            case let .structDecl(decl): [decl.name]
            case let .enumDecl(decl): [decl.name]
            case let .actorDecl(decl): [decl.name]
            case let .protocolDecl(decl): [decl.name]
            case let .functionDecl(decl): [decl.name]
            case let .typeAliasDecl(decl): [decl.name]
            case let .associatedTypeDecl(decl): [decl.name]
            case let .macroDecl(decl): [decl.name]
            case let .operatorDecl(decl): [decl.name]
            case let .precedenceGroupDecl(decl): [decl.name]
            case let .initializerDecl(decl): [decl.initKeyword]
            case let .deinitializerDecl(decl): [decl.deinitKeyword]
            case let .subscriptDecl(decl): [decl.subscriptKeyword]
            case let .enumCaseDecl(decl): decl.elements.map(\.name)
            case let .variableDecl(decl): decl.bindings.flatMap { identifiers(in: $0.pattern) }
            default: []
            }

            return tokens.map { [position(at: $0.positionAfterSkippingLeadingTrivia)] }
        }

        private func identifiers(in pattern: PatternSyntax) -> [TokenSyntax] {
            pattern.tokens(viewMode: .sourceAccurate).filter {
                if case .identifier = $0.tokenKind {
                    true
                } else {
                    false
                }
            }
        }

        /// The first line of the declaration, its attributes and the doc comments right above it included. A blank
        /// line or a plain comment ends the doc comments that belong to it.
        private func startLine(of decl: DeclSyntax) -> Int {
            var startLine = line(at: decl.positionAfterSkippingLeadingTrivia)
            var pieceEnd = decl.positionAfterSkippingLeadingTrivia
            var newlines = 0

            for piece in decl.leadingTrivia.reversed() {
                let pieceStart = pieceEnd - piece.sourceLength
                defer { pieceEnd = pieceStart }

                switch piece {
                case .spaces, .tabs:
                    continue
                case let .newlines(count), let .carriageReturns(count), let .carriageReturnLineFeeds(count):
                    newlines += count
                    if newlines > 1 {
                        return startLine
                    }
                case .docLineComment, .docBlockComment:
                    startLine = line(at: pieceStart)
                    newlines = 0
                default:
                    return startLine
                }
            }

            return startLine
        }

        private func line(at position: AbsolutePosition) -> Int {
            converter.location(for: position).line
        }

        private func position(at position: AbsolutePosition) -> Position {
            let location = converter.location(for: position)
            return Position(line: location.line, column: location.column)
        }
    }
}
