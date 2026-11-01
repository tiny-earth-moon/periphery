/// An explicit access modifier identical to the default access level of its enclosing context.
public struct RedundantAccessLevel: Hashable {
    /// The redundant explicit access level.
    public let accessibility: Accessibility
    /// The default access level of the enclosing context, nil at the top level (where it is `internal`).
    public let context: Accessibility?
}
