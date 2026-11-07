import PeripheryKit
import SourceGraph
import SystemPackage

/// A result to fix, located by the position of its name as the scan reported it.
public struct FixTarget: Hashable, Sendable {
    public let rule: FixRule
    public let name: String
    public let kind: Declaration.Kind
    public let file: FilePath
    public let line: Int
    public let column: Int
    /// The redundant access level, for `redundantAccessLevel`.
    public let accessibility: Accessibility?
    /// Whether the declaration carries an `override location=` comment, so its reported position is not its own.
    public let hasLocationOverride: Bool

    public init(
        rule: FixRule,
        name: String,
        kind: Declaration.Kind,
        file: FilePath,
        line: Int,
        column: Int,
        accessibility: Accessibility? = nil,
        hasLocationOverride: Bool = false
    ) {
        self.rule = rule
        self.name = name
        self.kind = kind
        self.file = file
        self.line = line
        self.column = column
        self.accessibility = accessibility
        self.hasLocationOverride = hasLocationOverride
    }

    /// The target of a scan result, or nil when no tier-1 rule applies to it.
    public init?(result: ScanResult) {
        guard let fixableKind = result.fixableKind else { return nil }

        let declaration = result.resultDeclaration
        let rule: FixRule
        var accessibility: Accessibility?

        switch fixableKind {
        case .redundantPublic: rule = .redundantPublic
        case .redundantOpen: rule = .redundantOpen
        case let .redundantAccessLevel(level):
            rule = .redundantAccessLevel
            accessibility = level
        case .emptyExtension: rule = .emptyExtension
        case .unusedImport: rule = .unusedImport
        case .superfluousIgnore: rule = .superfluousIgnore
        case .unusedParameter: rule = .unusedParameter
        }

        let location = declaration.location
        self.init(
            rule: rule,
            name: declaration.name,
            kind: declaration.kind,
            file: location.file.path,
            line: location.line,
            column: location.column,
            accessibility: accessibility,
            hasLocationOverride: declaration.commentCommands.locationOverride != nil
                || declaration.parent?.commentCommands.locationOverride != nil
        )
    }

    public var locationDescription: String {
        "\(file.string):\(line):\(column)"
    }
}
