import Configuration
import Foundation
import Shared

/// https://github.com/apple/swift/issues/56189
/// Older index stores do not contain references to `appendInterpolation` functions from their use in string literals;
/// Swift 6.4 records them (`KnownSwiftBugsTest`), the retainer stays for the older toolchains.
final class StringInterpolationAppendInterpolationRetainer: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        for declaration in graph.declarations(ofKind: .extensionStruct) {
            declaration.declarations.filter {
                $0.kind == .functionMethodInstance &&
                    $0.name.hasPrefix("appendInterpolation(")
            }.forEach {
                graph.markRetained($0)
            }
        }
    }
}
