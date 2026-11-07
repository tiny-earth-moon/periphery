import Configuration
import Foundation
import Shared

/// https://github.com/apple/swift/issues/56189
/// Older index stores do not contain references to `appendInterpolation` functions from their use in string literals;
/// Swift 6.4 records them (`KnownSwiftBugsTest`), so the retainer only runs on older toolchains.
final class StringInterpolationAppendInterpolationRetainer: SourceGraphMutator {
    static let firstVersionRecordingReference = "6.4"

    private let graph: SourceGraph
    private let swiftVersion: SwiftVersion

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion: SwiftVersion) {
        self.graph = graph
        self.swiftVersion = swiftVersion
    }

    func mutate() {
        guard swiftVersion.version.isVersion(lessThan: Self.firstVersionRecordingReference) else { return }

        for declaration in graph.declarations(ofKind: .extensionStruct) {
            declaration.declarations.filter {
                $0.kind == .functionMethodInstance &&
                    $0.name.hasPrefix("appendInterpolation(")
            }.forEach {
                graph.markRetained($0, reason: RetentionReason(Self.self, "appendInterpolation of a string interpolation type"))
            }
        }
    }
}
