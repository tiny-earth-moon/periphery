import Configuration
import Foundation
import Shared

final class SwiftUIRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration
    private static let specialProtocolNames = ["LibraryContentProvider"]
    private static let applicationDelegateAdaptorStructNames = ["UIApplicationDelegateAdaptor", "NSApplicationDelegateAdaptor"]
    /// SDK protocols whose only requirements are underscored. The index store records no `overrideOf` relation for
    /// them, so the witness is retained by name on every type conforming to the protocol.
    private static let underscoredRequirementsByProtocolUsr = [
        "s:7SwiftUI14TextFieldStyleP": ["_body(configuration:)"],
        "s:7SwiftUI10ShapeStyleP": ["_apply(to:)"],
    ]
    static let previewRegistryUsr = "s:21DeveloperToolsSupport15PreviewRegistryP"

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        retainSpecialProtocolConformances()
        retainApplicationDelegateAdaptors()
        retainUnderscoredProtocolRequirements()
        unretainPreviewMacroExpansions()
    }

    // MARK: - Private

    private func retainSpecialProtocolConformances() {
        var names = Self.specialProtocolNames

        if configuration.retainSwiftUIPreviews {
            names.append("PreviewProvider")
        }

        graph
            .declarations(ofKinds: [.class, .struct, .enum])
            .lazy
            .filter {
                self.graph.inheritedTypeReferences(of: $0).contains {
                    self.graph.isExternal($0) && $0.declarationKind == .protocol && names.contains($0.name)
                }
            }
            .forEach { graph.markRetainedWithAncestors($0, reason: RetentionReason(Self.self, "conforms to a SwiftUI protocol discovered at runtime")) }
    }

    private func retainUnderscoredProtocolRequirements() {
        for decl in graph.declarations(ofKinds: [.class, .struct, .enum]) {
            let witnessNames = decl.related
                .lazy
                .filter { $0.declarationKind == .protocol }
                .compactMap { Self.underscoredRequirementsByProtocolUsr[$0.usr] }
                .joined()

            for name in witnessNames {
                decl.declarations
                    .lazy
                    .filter { $0.kind == .functionMethodInstance && $0.name == name }
                    .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "SwiftUI requirement used at runtime")) }
            }
        }
    }

    private func retainApplicationDelegateAdaptors() {
        graph
            .mainAttributedDeclarations
            .lazy
            .flatMap(\.declarations)
            .filter { $0.kind == .varInstance }
            .filter {
                $0.references.contains {
                    ($0.declarationKind == .struct || $0.declarationKind == .enum) && Self.applicationDelegateAdaptorStructNames.contains($0.name)
                }
            }
            .forEach { graph.markRetained($0, reason: RetentionReason(Self.self, "SwiftUI requirement used at runtime")) }
    }

    private func unretainPreviewMacroExpansions() {
        guard !configuration.retainSwiftUIPreviews else { return }

        let macroReferences = graph.references(to: Self.previewRegistryUsr)
        guard !macroReferences.isEmpty else { return }

        for reference in macroReferences {
            if let parent = reference.parent, parent.isImplicit {
                graph.unmarkRetained(parent)

                for decl in parent.declarations {
                    graph.unmarkRetained(decl)
                }
            }
        }
    }
}
