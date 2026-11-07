/// How declarations that may be used by a build the index store does not contain are retained.
public enum PlatformConditionalRetention: String, CaseIterable, Equatable, Sendable {
    /// Like `allClauses`, also narrowing `#if` blocks nested in another one, and not retaining a declaration marked
    /// `@available(X, unavailable)` once the index holds a build for `X` and one for a platform where it is available.
    case auto
    /// Retain the names written in the platform `#if` clauses no indexed build compiled (nested blocks whole), and the
    /// declarations marked `@available(X, unavailable)`.
    case allClauses = "all-clauses"
    /// Retain neither.
    case off

    public static let `default` = PlatformConditionalRetention.allClauses
}
