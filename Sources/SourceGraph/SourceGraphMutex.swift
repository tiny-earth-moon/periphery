import Foundation
import Synchronization

/// A shareable wrapper around `SourceGraph` providing synchronized access.
/// `Mutex` is non-copyable, so this reference type allows multiple indexers
/// to share the same lock-protected graph during concurrent indexing.
///
/// `@unchecked Sendable` invariant: the graph's own storage is only reached
/// inside `withLock`, and `body` must not keep the graph after it returns.
/// The lock does not cover the `Declaration` and `Reference` objects the
/// graph holds: a concurrent indexing job may only mutate the objects it
/// created itself. `SourceGraph` is not `Sendable`, so the compiler cannot
/// check either rule.
public final class SourceGraphMutex: @unchecked Sendable {
    private let graph: Mutex<SourceGraph>

    public init(graph: SourceGraph) {
        self.graph = Mutex(graph)
    }

    @discardableResult
    public func withLock<T>(_ body: (SourceGraph) throws -> T) rethrows -> T {
        try graph.withLock { try body($0) }
    }
}
