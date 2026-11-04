import Foundation

/// A shareable wrapper around `SourceGraph` providing synchronized access.
/// This reference type allows multiple indexers to share the same
/// lock-protected graph during concurrent indexing. The caller keeps its own
/// reference to the graph, so a `Mutex` taking ownership of it does not apply.
///
/// `@unchecked Sendable` invariant: the graph's own storage is only reached
/// inside `withLock`, and `body` must not keep the graph after it returns.
/// The lock does not cover the `Declaration` and `Reference` objects the
/// graph holds: a concurrent indexing job may only mutate the objects it
/// created itself. `SourceGraph` is not `Sendable`, so the compiler cannot
/// check either rule.
public final class SourceGraphMutex: @unchecked Sendable {
    private let lock = NSLock()
    private let graph: SourceGraph

    public init(graph: SourceGraph) {
        self.graph = graph
    }

    @discardableResult
    public func withLock<T>(_ body: (SourceGraph) throws -> T) rethrows -> T {
        try lock.withLock { try body(graph) }
    }
}
