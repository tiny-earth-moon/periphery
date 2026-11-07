import Configuration
import Foundation
import Shared

/// Retains types conforming to App Intents protocols.
///
/// Types conforming to these protocols are discovered and invoked by the system at runtime,
/// so they should not be reported as unused.
final class AppIntentsRetainer: SourceGraphMutator {
    private let graph: SourceGraph

    /// USR prefix for Swift symbols from the AppIntents module.
    /// Swift USRs encode the module name with a length prefix: "s:<length><module_name>..."
    /// For AppIntents (10 characters), this becomes "s:10AppIntents".
    private static let appIntentsModuleUsrPrefix = "s:10AppIntents"

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    /// Static properties that the App Intents metadata processor reads by name at build time. The
    /// `description` requirement is optional, so a property with an inferred non-optional type does not witness
    /// it and the index records no relation to the protocol.
    private static let metadataPropertyNames: Set<String> = ["description"]

    func mutate() {
        let retainedDeclarations = graph
            .declarations(ofKinds: [.class, .struct, .enum])
            .filter {
                graph.inheritedTypeReferences(of: $0).contains {
                    graph.isExternal($0) &&
                        $0.declarationKind == .protocol &&
                        $0.usr.hasPrefix(Self.appIntentsModuleUsrPrefix)
                }
            }

        for declaration in retainedDeclarations {
            graph.markRetainedWithAncestors(declaration, reason: RetentionReason(Self.self, "conforms to an App Intents protocol"))

            declaration.declarations
                .filter { $0.kind == .varStatic && Self.metadataPropertyNames.contains($0.name) }
                .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "member of an App Intents type")) }
        }
    }
}
