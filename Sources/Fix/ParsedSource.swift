import SwiftSyntax

/// A parsed source file and the byte ranges that removing a piece of it takes along.
struct ParsedSource {
    let bytes: [UInt8]
    let tree: SourceFileSyntax
    let converter: SourceLocationConverter

    init(path: String, bytes: [UInt8], tree: SourceFileSyntax) {
        self.bytes = bytes
        self.tree = tree
        converter = SourceLocationConverter(fileName: path, tree: tree)
    }

    /// The token that starts exactly at the line and column a result reports, columns counting UTF-8 bytes.
    func token(atLine line: Int, column: Int) -> TokenSyntax? {
        guard line >= 1, column >= 1 else { return nil }

        let position = converter.position(ofLine: line, column: column)
        guard position.utf8Offset < bytes.count,
              converter.location(for: position).line == line,
              converter.location(for: position).column == column,
              let token = tree.token(at: position),
              token.positionAfterSkippingLeadingTrivia == position
        else { return nil }

        return token
    }

    /// The range that removes a node or a comment, from `start` to `end`. When the removed text is alone on its lines,
    /// the range takes the indentation and one trailing newline, and one of two blank lines that would end up next to
    /// each other; otherwise it takes the spaces that separate it from the rest of the line.
    func removalRange(from start: Int, to end: Int) -> Range<Int> {
        var lineStart = start
        while lineStart > 0, isHorizontalSpace(bytes[lineStart - 1]) {
            lineStart -= 1
        }
        var lineEnd = end
        while lineEnd < bytes.count, isHorizontalSpace(bytes[lineEnd]) {
            lineEnd += 1
        }

        let startsLine = lineStart == 0 || bytes[lineStart - 1] == newline
        let endsLine = lineEnd == bytes.count || bytes[lineEnd] == newline || bytes[lineEnd] == carriageReturn

        switch (startsLine, endsLine) {
        case (true, true):
            var upperBound = lineEnd
            if upperBound < bytes.count, bytes[upperBound] == carriageReturn {
                upperBound += 1
            }
            if upperBound < bytes.count, bytes[upperBound] == newline {
                upperBound += 1
            }
            var lowerBound = lineStart
            let followsBlankLine = lowerBound == 0 || (lowerBound >= 2 && bytes[lowerBound - 2] == newline)
            if followsBlankLine, upperBound < bytes.count, bytes[upperBound] == newline {
                upperBound += 1
            } else if upperBound == bytes.count, lowerBound >= 2, bytes[lowerBound - 2] == newline {
                lowerBound -= 1
            }
            return lowerBound ..< upperBound
        case (false, true):
            return lineStart ..< lineEnd
        case (_, false):
            return start ..< lineEnd
        }
    }

    /// The range that removes a whole statement or declaration with its attached doc comment and trailing comment.
    /// Comments separated from it by a blank line, and comments that are not doc comments, stay.
    func statementRemovalRange(_ node: some SyntaxProtocol) -> Range<Int> {
        var start = node.positionAfterSkippingLeadingTrivia.utf8Offset
        if let firstToken = node.firstToken(viewMode: .sourceAccurate) {
            start = attachedDocCommentStart(of: firstToken) ?? start
        }
        return removalRange(from: start, to: node.endPosition.utf8Offset)
    }

    // MARK: - Private

    private let newline = UInt8(ascii: "\n")
    private let carriageReturn = UInt8(ascii: "\r")

    private func isHorizontalSpace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t")
    }

    /// The offset of the first doc comment that is attached to the token, line after line without a blank line.
    private func attachedDocCommentStart(of token: TokenSyntax) -> Int? {
        let pieces = token.leadingTrivia.offsetPieces(startingAt: token.position.utf8Offset)
        var index = pieces.count - 1
        var start: Int?

        func skipHorizontalSpace() {
            while index >= 0, pieces[index].piece.isHorizontalSpace {
                index -= 1
            }
        }

        skipHorizontalSpace()
        while index >= 0, pieces[index].piece.isSingleNewline {
            var commentIndex = index - 1
            while commentIndex >= 0, pieces[commentIndex].piece.isHorizontalSpace {
                commentIndex -= 1
            }
            guard commentIndex >= 0, pieces[commentIndex].piece.isDocComment else { break }

            start = pieces[commentIndex].offset
            index = commentIndex - 1
            skipHorizontalSpace()
        }
        return start
    }
}

struct OffsetTriviaPiece {
    let piece: TriviaPiece
    let offset: Int

    var range: Range<Int> {
        offset ..< offset + piece.sourceLength.utf8Length
    }
}

extension Trivia {
    func offsetPieces(startingAt start: Int) -> [OffsetTriviaPiece] {
        var offset = start
        return pieces.map { piece in
            defer { offset += piece.sourceLength.utf8Length }
            return OffsetTriviaPiece(piece: piece, offset: offset)
        }
    }
}

extension TriviaPiece {
    var isHorizontalSpace: Bool {
        switch self {
        case .spaces, .tabs: true
        default: false
        }
    }

    var isSingleNewline: Bool {
        switch self {
        case .newlines(1), .carriageReturnLineFeeds(1), .carriageReturns(1): true
        default: false
        }
    }

    var isDocComment: Bool {
        switch self {
        case .docLineComment, .docBlockComment: true
        default: false
        }
    }

    /// The text of a comment, nil for any other piece.
    var commentText: (text: String, markerLength: Int)? {
        switch self {
        case let .lineComment(text), let .blockComment(text): (text, 2)
        case let .docLineComment(text), let .docBlockComment(text): (text, 3)
        default: nil
        }
    }
}
