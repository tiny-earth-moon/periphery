/// A name written at a pattern position that may refer to an enum case.
public struct EnumCasePatternSite: Hashable {
    /// The shape of a collected name.
    public enum Shape: Hashable {
        /// `.name` or `Type.name`.
        case name
        /// The callee of `.name(...)` or `Type.name(...)`.
        case call
    }

    public let shape: Shape
    /// The location of the callee whose argument holds this name, `nil` at the top of the pattern.
    public let enclosingCall: Location?

    public init(shape: Shape, enclosingCall: Location?) {
        self.shape = shape
        self.enclosingCall = enclosingCall
    }
}
