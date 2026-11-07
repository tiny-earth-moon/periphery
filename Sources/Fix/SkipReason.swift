/// Why a result was not fixed.
public enum SkipReason: Error, Hashable, Sendable, CustomStringConvertible {
    case locationMismatch
    case indexExcluded
    case generatedFile
    case locationOverride
    case exportedImport
    case testableImport
    case conditionalImport
    case changedSinceIndexing
    case uncommittedChanges
    case notInGitRepository
    case outsideRepository
    case nestedRepository
    case symbolicLink
    case unreadableFile
    case overlappingEdit
    case modifierNotFound
    case multipleBindings
    case extensionNotEmpty
    case ignoreCommentNotFound
    case partialParameterIgnore

    public var description: String {
        switch self {
        case .locationMismatch: "location mismatch"
        case .indexExcluded: "index-excluded file"
        case .generatedFile: "generated file"
        case .locationOverride: "location-override comment"
        case .exportedImport: "exported import"
        case .testableImport: "testable import"
        case .conditionalImport: "conditional import"
        case .changedSinceIndexing: "file changed since indexing"
        case .uncommittedChanges: "uncommitted changes, use --allow-dirty"
        case .notInGitRepository: "not in a git repository, use --allow-dirty"
        case .outsideRepository: "outside the git repository of the project"
        case .nestedRepository: "in a submodule or a nested git repository"
        case .symbolicLink: "symbolic link"
        case .unreadableFile: "unreadable file"
        case .overlappingEdit: "overlapping edit"
        case .modifierNotFound: "modifier not found"
        case .multipleBindings: "declaration with several bindings"
        case .extensionNotEmpty: "extension not empty"
        case .ignoreCommentNotFound: "ignore comment not found"
        case .partialParameterIgnore: "some ignored parameters are still unused"
        }
    }
}
