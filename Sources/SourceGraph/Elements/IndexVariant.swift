import Foundation

/// A build an index unit was compiled for: its target triple, and whether it was compiled without optimization.
///
/// The configuration name (`Debug`, `Release`, a custom one) is not recorded by index units, so it cannot be known;
/// only the optimization mode is.
public struct IndexVariant: Hashable, Comparable, CustomStringConvertible {
    public let triple: String
    /// `false` when the unit was compiled without optimization, as in a debug build.
    public let isOptimized: Bool

    public init(triple: String, isOptimized: Bool) {
        self.triple = triple
        self.isOptimized = isOptimized
    }

    public var description: String {
        isOptimized ? "\(triple) (optimized)" : triple
    }

    /// The platform names `@available` accepts that apply to this build, or `nil` when the triple is not an Apple
    /// platform known with certainty. A Mac Catalyst build is also an iOS build, as it inherits iOS availability.
    public var availabilityPlatforms: Set<String>? {
        let components = triple.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 3 || components.count == 4, components[1] == "apple" else { return nil }

        let osName = String(components[2].prefix { $0.isLetter })
        let environment = components.count == 4 ? components[3] : nil

        switch (osName, environment) {
        case ("macosx", nil), ("macos", nil):
            return ["macOS", "OSX"]
        case ("ios", "macabi"):
            return ["iOS", "macCatalyst"]
        case ("ios", nil), ("ios", "simulator"):
            return ["iOS"]
        case ("tvos", nil), ("tvos", "simulator"):
            return ["tvOS"]
        case ("watchos", nil), ("watchos", "simulator"):
            return ["watchOS"]
        case ("xros", nil), ("xros", "simulator"), ("visionos", nil), ("visionos", "simulator"):
            return ["visionOS"]
        default:
            return nil
        }
    }

    public static func < (lhs: IndexVariant, rhs: IndexVariant) -> Bool {
        (lhs.triple, lhs.isOptimized ? 1 : 0) < (rhs.triple, rhs.isOptimized ? 1 : 0)
    }

    /// Whether the index holds, for a declaration unavailable on `unavailablePlatforms`, both a build for one of these
    /// platforms and a build for a platform where the declaration is available. Its references from the platforms
    /// where it is available are then in the index, and those from the platforms that were not built can only be
    /// written in `#if` clauses no build compiled, whose names are retained.
    ///
    /// Never true with fewer than two builds, nor when one of them is not a known Apple platform.
    public static func cover(unavailablePlatforms: Set<String>, in variants: Set<IndexVariant>) -> Bool {
        guard !unavailablePlatforms.isEmpty else { return false }

        let platforms = variants.map(\.availabilityPlatforms)
        guard !platforms.contains(where: { $0 == nil }) else { return false }

        let builtPlatforms = platforms.compactMap(\.self)
        let buildsUnavailablePlatform = builtPlatforms.contains { !$0.isDisjoint(with: unavailablePlatforms) }
        let buildsAvailablePlatform = builtPlatforms.contains { $0.isDisjoint(with: unavailablePlatforms) }

        return buildsUnavailablePlatform && buildsAvailablePlatform
    }
}
