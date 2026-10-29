import Configuration
import Foundation
import Shared

/// Retains localized string declarations from xcstrings files that are used in Swift source code.
final class LocalizedStringRetainer: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        let usedKeys = graph.usedLocalizedStringKeys

        guard !usedKeys.isEmpty else { return }

        let matcher = LocalizedStringKeyMatcher(usedKeys: usedKeys)

        for declaration in graph.declarations(ofKind: .localizedString) where matcher.matches(declaration.name) {
            graph.markRetained(declaration)
        }
    }
}
