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

/// A Swift call that creates a Metal library, or a binary archive, from something other than the project's `.metal`
/// files, so that it may declare functions outskirts cannot read.
public struct MetalRuntimeLibrarySite: Hashable, Comparable {
    /// The creating call, e.g. `makeLibrary(source:)`.
    public let call: String
    public let location: Location

    public init(call: String, location: Location) {
        self.call = call
        self.location = location
    }

    public static func < (lhs: MetalRuntimeLibrarySite, rhs: MetalRuntimeLibrarySite) -> Bool {
        lhs.location < rhs.location
    }
}
