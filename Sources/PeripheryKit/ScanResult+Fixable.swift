import SourceGraph

public extension ScanResult {
    /// The result kinds that `outskirts fix` knows how to apply.
    enum FixableKind: Equatable, Sendable {
        case redundantPublic
        case redundantOpen
        case redundantAccessLevel(Accessibility)
        case emptyExtension
        case unusedImport
        case superfluousIgnore
        case unusedParameter
        case missingFinal
    }

    /// The fix this result calls for, or nil when it cannot be fixed by a syntax-only edit.
    var fixableKind: FixableKind? {
        switch annotation {
        case .redundantPublicAccessibility:
            .redundantPublic
        case .redundantOpenAccessibility:
            .redundantOpen
        case let .redundantAccessLevel(redundant):
            .redundantAccessLevel(redundant.accessibility)
        case .emptyExtension:
            .emptyExtension
        case .superfluousIgnoreCommand:
            .superfluousIgnore
        case .unused where declaration.kind == .module:
            .unusedImport
        case .unused where declaration.kind == .varParameter:
            .unusedParameter
        case .missingFinal where declaration.kind == .class:
            .missingFinal
        default:
            nil
        }
    }

    /// The declaration the result is about.
    var resultDeclaration: Declaration {
        declaration
    }
}
