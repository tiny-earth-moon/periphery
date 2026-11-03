import Foundation

/// A Swift expression that names a Metal function: the `name:` argument of `makeFunction(name:)` or
/// `MTLFunctionStitchingFunctionNode(name:)`, or the value assigned to `MTLFunctionDescriptor.name`.
public struct MetalFunctionNameReference: Hashable {
    /// The function name, `nil` when the expression is not a plain string literal and may name any function.
    public let name: String?
    public let location: Location

    public init(name: String?, location: Location) {
        self.name = name
        self.location = location
    }
}
