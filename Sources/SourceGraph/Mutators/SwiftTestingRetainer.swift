import Configuration
import Foundation
import Shared

/// Retains Swift Testing declarations.
/// https://developer.apple.com/xcode/swift-testing/
final class SwiftTestingRetainer: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        for decl in graph.declarations(ofKinds: [.class, .struct]) {
            guard decl.location.file.importsSwiftTesting else { continue }

            if decl.attributes.contains(where: { $0.name == "Suite" }) {
                graph.markRetained(decl, reason: RetentionReason(Self.self, "@Suite"))
            }
        }

        for decl in graph.declarations(ofKinds: [.functionFree, .functionMethodInstance, .functionMethodClass, .functionMethodStatic]) {
            guard decl.location.file.importsSwiftTesting else { continue }

            if decl.attributes.contains(where: { $0.name == "Test" }) {
                graph.markRetained(decl, reason: RetentionReason(Self.self, "@Test"))

                if let parent = decl.parent {
                    graph.markRetained(parent, reason: RetentionReason(Self.self, "type of the @Test function \(decl.name)"))
                }
            }
        }
    }
}
