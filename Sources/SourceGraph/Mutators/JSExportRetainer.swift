import Configuration
import Foundation
import Shared

/// Retains protocols that inherit, directly or through another protocol, from JavaScriptCore's `JSExport`,
/// their declared members, and the members of conforming types that satisfy those requirements.
/// JavaScript can call all of them, which outskirts cannot observe.
///
/// Must come before ProtocolConformanceReferenceBuilder, which inverts the references from
/// conforming members to protocol requirements that this mutator relies on.
final class JSExportRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        guard configuration.retainJsAccessible else { return }

        for proto in graph.declarations(ofKind: .protocol) where inheritsJSExport(proto) {
            graph.markRetained(proto, reason: RetentionReason(Self.self, "retain_js_accessible"))

            for member in proto.declarations {
                graph.markRetained(member, reason: RetentionReason(Self.self, "retain_js_accessible"))

                for reference in graph.references(to: member) where reference.kind == .related {
                    if let implementation = reference.parent {
                        graph.markRetained(implementation, reason: RetentionReason(Self.self, "retain_js_accessible"))
                    }
                }
            }
        }
    }

    // MARK: - Private

    private func inheritsJSExport(_ proto: Declaration) -> Bool {
        graph.inheritedTypeReferences(of: proto).contains {
            $0.declarationKind == .protocol && $0.name == "JSExport"
        }
    }
}
