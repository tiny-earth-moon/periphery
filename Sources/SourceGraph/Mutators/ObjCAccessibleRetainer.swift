import Configuration
import Foundation
import Shared

final class ObjCAccessibleRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        guard configuration.retainObjcAccessible || configuration.retainObjcAnnotated else { return }

        for decl in graph.declarations(ofKinds: Declaration.Kind.accessibleKinds) {
            guard decl.attributes.contains(where: { $0.name == "objc" }) ||
                decl.attributes.contains(where: { $0.name == "objc.name" }) ||
                decl.attributes.contains(where: { $0.name == "objcMembers" }) else { continue }

            decl.isObjcAccessible = true
            graph.markRetained(decl, reason: RetentionReason(Self.self, "\(configuration.retainObjcAccessible ? "retain_objc_accessible" : "retain_objc_annotated"), @objc or @objcMembers"))

            if configuration.retainObjcAnnotated {
                if decl.attributes.contains(where: { $0.name == "objcMembers" }) || decl.kind == .protocol || decl.kind == .extensionClass {
                    for declaration in decl.declarations {
                        declaration.isObjcAccessible = true
                        graph.markRetained(declaration, reason: RetentionReason(Self.self, "retain_objc_annotated, member of an @objcMembers type, @objc protocol or extension"))
                    }
                }
            }
        }

        if configuration.retainObjcAnnotated {
            for extDecl in graph.declarations(ofKind: .extensionClass) {
                if let extendedClass = try graph.extendedDeclaration(forExtension: extDecl),
                   extendedClass.attributes.contains(where: { $0.name == "objcMembers" })
                {
                    for declaration in extDecl.declarations {
                        declaration.isObjcAccessible = true
                        graph.markRetained(declaration, reason: RetentionReason(Self.self, "retain_objc_annotated, member of an @objcMembers type, @objc protocol or extension"))
                    }
                }
            }
        }
    }
}
