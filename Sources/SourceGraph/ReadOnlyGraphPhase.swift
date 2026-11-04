/// Carries graph objects into the concurrent jobs of a mutator phase that only reads the graph.
///
/// `@unchecked Sendable` invariant: while the jobs run, nothing mutates the graph, nor the declarations and
/// references it holds; the jobs only read them and mutate the objects they create themselves, which are added
/// to the graph afterwards, on the calling thread. `SourceGraph`, `Declaration` and `Reference` are mutable
/// classes, so the compiler cannot check this.
struct ReadOnlyGraphPhase<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
