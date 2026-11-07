import Foundation

public struct ImportStatement {
    public let module: String
    public let isTestable: Bool
    public let isExported: Bool
    public let isConditional: Bool
    public let location: Location
    public let endLocation: Location
    public let commentCommands: [CommentCommand]
    public let range: DeclarationRange?

    public init(
        module: String,
        isTestable: Bool,
        isExported: Bool,
        isConditional: Bool,
        location: Location,
        endLocation: Location,
        commentCommands: [CommentCommand],
        range: DeclarationRange? = nil
    ) {
        self.module = module
        self.isTestable = isTestable
        self.isExported = isExported
        self.isConditional = isConditional
        self.location = location
        self.endLocation = endLocation
        self.commentCommands = commentCommands
        self.range = range
    }

    /// Whether the location lies within the import statement, e.g. the reference to the declaration named
    /// by a scoped import such as `import struct Module.Type`.
    public func contains(_ other: Location) -> Bool {
        let start = (location.line, location.column)
        let end = (endLocation.line, endLocation.column)
        let point = (other.line, other.column)
        return start <= point && point < end && other.file == location.file
    }
}
