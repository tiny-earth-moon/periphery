import Configuration

/// A kind of result that `outskirts fix` applies with a syntax-only edit.
public enum FixRule: String, CaseIterable, Sendable {
    case redundantPublic = "redundant-public"
    case redundantOpen = "redundant-open"
    case redundantAccessLevel = "redundant-access-level"
    case emptyExtension = "empty-extension"
    case unusedImport = "unused-import"
    case superfluousIgnore = "superfluous-ignore"
    case unusedParameter = "unused-parameter"

    /// Whether the analysis that produces the results of this rule is enabled. Opt-in analyses are only fixed when
    /// they are enabled on the command line or in the configuration file.
    public func isEnabled(in configuration: Configuration) -> Bool {
        switch self {
        case .redundantPublic:
            !configuration.disableRedundantPublicAnalysis
        case .redundantOpen:
            configuration.enableOpenFinalAnalysis
        case .redundantAccessLevel:
            configuration.enableRedundantAccessLevelAnalysis
        case .emptyExtension:
            configuration.enableEmptyExtensionAnalysis
        case .unusedImport:
            !configuration.disableUnusedImportAnalysis
        case .superfluousIgnore:
            configuration.superfluousIgnoreComments
        case .unusedParameter:
            true
        }
    }
}
