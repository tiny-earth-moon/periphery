import Foundation

// A plain comment, not part of the declaration below.

/// A documented type.
/// Its second line.
@available(macOS 10.15, *)
public final class RangeFixtureDocumented {
    @available(*, deprecated) @inline(never)
    func attributed() {}

    struct Nested {
        let value: Int
    }

    func parameters(first: Int, _ second: String) {}
}

/// Detached by the plain comment below.
// A plain comment.
enum RangeFixtureCases {
    case one, two
}

/// Detached by the blank line below.

extension RangeFixtureDocumented {}
