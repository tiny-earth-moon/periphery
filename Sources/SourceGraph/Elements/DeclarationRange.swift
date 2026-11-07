/// A 1-based line and column in a source file, the column counted in UTF-8 bytes like `Location`.
public struct SourcePosition: Hashable, Sendable {
    // 32-bit storage keeps a range small, as one is stored per declaration.
    private let storedLine: Int32
    private let storedColumn: Int32

    public var line: Int {
        Int(storedLine)
    }

    public var column: Int {
        Int(storedColumn)
    }

    public init(line: Int, column: Int) {
        storedLine = Int32(clamping: line)
        storedColumn = Int32(clamping: column)
    }
}

/// The extent of a declaration in its source file, from the syntax tree.
///
/// The positions nest: `docCommentStart` < `attributesStart` < `start` < `end`. The declaration syntax node covers
/// `attributesStart ?? start` up to `end`, and its doc comment is included from `docCommentStart`. The elements of a
/// declaration that has several, e.g. `case a, b` or `let a = 1, b = 2`, share the range of the whole declaration.
public struct DeclarationRange: Hashable, Sendable {
    /// The first modifier or keyword, after the attributes.
    public let start: SourcePosition
    /// The position just after the last character of the declaration, trailing comments excluded.
    public let end: SourcePosition
    /// The first attribute, when the declaration has any.
    public let attributesStart: SourcePosition?
    /// The first of the doc comments (`///` or `/** */`) right above the declaration, when it has any. A blank line
    /// or a plain comment ends the doc comments that belong to it.
    public let docCommentStart: SourcePosition?

    public init(start: SourcePosition, end: SourcePosition, attributesStart: SourcePosition? = nil, docCommentStart: SourcePosition? = nil) {
        self.start = start
        self.end = end
        self.attributesStart = attributesStart
        self.docCommentStart = docCommentStart
    }
}
