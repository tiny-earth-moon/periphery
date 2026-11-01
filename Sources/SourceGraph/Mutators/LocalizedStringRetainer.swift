import Configuration
import Foundation
import Shared

/// Retains localized string declarations from xcstrings files that are used in Swift source code.
///
/// A key built at runtime retains the catalogue keys starting with its literal prefix (every key without a prefix):
/// in the catalogues of the calling module for a `bundle: .module` lookup, in every catalogue otherwise. A catalogue
/// with an unknown owning module is matched against the runtime keys of every module.
/// Based on agoodkind/periphery@544a77d and 5c5af4c by Alex Goodkind.
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

        let modulePrefixes = graph.runtimeLocalizedStringKeyPrefixesByModule
        let globalPrefixes = graph.runtimeLocalizedStringKeyPrefixes

        guard !matcher.isEmpty || !modulePrefixes.isEmpty || !globalPrefixes.isEmpty else { return }

        let allModulePrefixes = modulePrefixes.values.reduce(into: Set<String>()) { $0.formUnion($1) }

        for declaration in graph.declarations(ofKind: .localizedString) {
            let key = declaration.name
            let owners = declaration.location.file.modules
            let prefixes = owners.isEmpty
                ? globalPrefixes.union(allModulePrefixes)
                : owners.reduce(into: globalPrefixes) { $0.formUnion(modulePrefixes[$1] ?? []) }

            if matcher.matches(key) || prefixes.contains(where: { key.hasPrefix($0) }) {
                graph.markRetained(declaration)
            }
        }
    }
}
