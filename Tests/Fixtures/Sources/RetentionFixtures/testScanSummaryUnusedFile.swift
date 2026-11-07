import Foundation

/// A type that nothing uses.
/// Its doc comment counts as removable.
@available(macOS 10.15, *)
final class SummaryUnusedClass {
    struct Nested {
        func nestedMethod() {}
    }

    func method() {}
}

// A plain comment, separated by a blank line, is not attached.

struct SummaryUnusedStruct {
    var value = 0
}

extension SummaryUnusedStruct {
    func extensionMethod() {}
}
