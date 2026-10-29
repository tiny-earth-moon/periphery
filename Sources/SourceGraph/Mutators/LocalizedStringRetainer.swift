import Configuration
import Foundation
import Shared

/// Retains localized string declarations from xcstrings files that are used in Swift source code.
final class LocalizedStringRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        let matcher = try LocalizedStringKeyMatcher(
            usedKeys: graph.usedLocalizedStringKeys,
            patterns: configuration.localizedStringKeyPatterns
        )

        guard !matcher.isEmpty else { return }

        for declaration in graph.declarations(ofKind: .localizedString) where matcher.matches(declaration.name) {
            graph.markRetained(declaration)
        }
    }
}
