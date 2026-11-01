import ArgumentParser
import Shared

/// Options of the Bazel mode, removed in 3.13.0. They stay declared, hidden from the help, so that using one fails with
/// an explicit error instead of the generic "Unknown option" of ArgumentParser.
struct RemovedBazelOptions: ParsableArguments {
    @Flag(help: .hidden)
    var bazel: Bool = false

    @Option(help: .hidden)
    var bazelFilter: String?

    @Option(help: .hidden)
    var bazelQuery: String?

    @Option(help: .hidden)
    var bazelIndexStore: String?

    @Flag(help: .hidden)
    var bazelCheckVisibility: Bool = false

    func rejectUse() throws {
        let used = [
            (bazel, "--bazel"),
            (bazelFilter != nil, "--bazel-filter"),
            (bazelQuery != nil, "--bazel-query"),
            (bazelIndexStore != nil, "--bazel-index-store"),
            (bazelCheckVisibility, "--bazel-check-visibility"),
        ]

        if let option = used.first(where: \.0)?.1 {
            throw PeripheryError.removedBazelOption("'\(option)'")
        }
    }
}
