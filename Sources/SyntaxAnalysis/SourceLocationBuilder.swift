import SourceGraph
import SwiftSyntax

public final class SourceLocationBuilder {
    private let file: SourceFile
    private let locationConverter: SourceLocationConverter

    public init(file: SourceFile, locationConverter: SourceLocationConverter) {
        self.file = file
        self.locationConverter = locationConverter
    }

    public func location(at position: AbsolutePosition) -> Location {
        let location = locationConverter.location(for: position)
        return Location(file: file,
                        line: location.line,
                        column: location.column)
    }

    func declarationRange(of node: some SyntaxProtocol, attributes: AttributeListSyntax?) -> DeclarationRange {
        locationConverter.declarationRange(of: node, attributes: attributes)
    }
}

extension SourceLocationConverter {
    /// The range of a declaration node, read from the node already parsed for the shared syntax walk. `end` defaults
    /// to the end of the node.
    func declarationRange(of node: some SyntaxProtocol, attributes: AttributeListSyntax?, end: AbsolutePosition? = nil) -> DeclarationRange {
        let nodeStart = node.positionAfterSkippingLeadingTrivia
        var start = nodeStart
        var attributesStart: SourcePosition?

        if let attributes, !attributes.isEmpty,
           let next = attributes.lastToken(viewMode: .sourceAccurate)?.nextToken(viewMode: .sourceAccurate)
        {
            attributesStart = sourcePosition(at: nodeStart)
            start = next.positionAfterSkippingLeadingTrivia
        }

        return DeclarationRange(
            start: sourcePosition(at: start),
            end: sourcePosition(at: end ?? node.endPositionBeforeTrailingTrivia),
            attributesStart: attributesStart,
            docCommentStart: docCommentStart(in: node.leadingTrivia, before: nodeStart).map { sourcePosition(at: $0) }
        )
    }

    // MARK: - Private

    private func sourcePosition(at position: AbsolutePosition) -> SourcePosition {
        let location = location(for: position)
        return SourcePosition(line: location.line, column: location.column)
    }

    /// The start of the doc comments right above the node. A blank line or a plain comment ends the doc comments that
    /// belong to it.
    private func docCommentStart(in trivia: Trivia, before nodeStart: AbsolutePosition) -> AbsolutePosition? {
        var docCommentStart: AbsolutePosition?
        var pieceEnd = nodeStart
        var newlines = 0

        for piece in trivia.reversed() {
            let pieceStart = pieceEnd - piece.sourceLength
            defer { pieceEnd = pieceStart }

            switch piece {
            case .spaces, .tabs:
                continue
            case let .newlines(count), let .carriageReturns(count), let .carriageReturnLineFeeds(count):
                newlines += count
                if newlines > 1 {
                    return docCommentStart
                }
            case .docLineComment, .docBlockComment:
                docCommentStart = pieceStart
                newlines = 0
            default:
                return docCommentStart
            }
        }

        return docCommentStart
    }
}
