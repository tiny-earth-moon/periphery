import Configuration
import Foundation
import Shared

final class UsedDeclarationMarker: SourceGraphMutator {
    private static let swiftUIViewUsr = "s:7SwiftUI4ViewP"

    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        removeErroneousProtocolReferences()
        markUsed(graph.retainedDeclarations)

        markUsed(graph.rootReferences.compactMapSet { graph.declaration(withUsr: $0.usr) })
        markLivePreviewExpansionsUsed()

        ignoreUnusedDescendents(in: graph.rootDeclarations,
                                unusedDeclarations: graph.unusedDeclarations)
    }

    // MARK: - Private

    /// Removes references from protocol member decls to conforming decls that have a dereferenced ancestor.
    private func removeErroneousProtocolReferences() {
        // Evaluate ancestor dereference status from a stable pre-mutation snapshot to avoid
        // order-dependent behavior when iterating sets and removing references.
        let dereferencedDeclarations = graph.allDeclarations.filter {
            !(graph.isRetained($0) || graph.hasReferences(to: $0))
        }

        let dereferencedAncestors = Set(dereferencedDeclarations)
        var referencesToRemove = Set<Reference>()

        for protocolDecl in graph.declarations(ofKind: .protocol) {
            for memberDecl in protocolDecl.declarations {
                for relatedRef in memberDecl.related {
                    guard let relatedDecl = graph.declaration(withUsr: relatedRef.usr) else { continue }

                    let hasDereferencedAncestor = relatedDecl.ancestralDeclarations.contains {
                        dereferencedAncestors.contains($0)
                    }

                    if hasDereferencedAncestor {
                        referencesToRemove.insert(relatedRef)
                    }
                }
            }
        }

        for reference in referencesToRemove {
            graph.remove(reference)
        }
    }

    /// Marks the declarations, and everything reachable from them through references and related references, as
    /// used. The walk uses an explicit worklist because a reference chain can be arbitrarily long and walking it by
    /// recursion overflows the stack.
    private func markUsed(_ declarations: Set<Declaration>) {
        var pending = Array(declarations)

        while let declaration = pending.popLast() {
            guard !graph.isUsed(declaration) else { continue }

            graph.markUsed(declaration)

            for reference in [declaration.references, declaration.related].joined() {
                if let referenced = graph.declaration(withUsr: reference.usr), !graph.isUsed(referenced) {
                    pending.append(referenced)
                }
            }
        }
    }

    /// Marks used each `#Preview` expansion that previews a used SwiftUI view, along with the code
    /// it references. Previews that only reference unused code stay unused.
    private func markLivePreviewExpansionsUsed() {
        var pendingPreviews = graph.references(to: SwiftUIRetainer.previewRegistryUsr)
            .compactMap(\.parent)
            .filter { $0.isImplicit && !graph.isUsed($0) }
            .mapSet { $0 }

        while true {
            let livePreviews = pendingPreviews.filter(previewsUsedView)
            guard !livePreviews.isEmpty else { break }

            pendingPreviews.subtract(livePreviews)
            markUsed(livePreviews.flatMapSet { $0.descendentDeclarations.union([$0]) })
        }
    }

    private func previewsUsedView(_ preview: Declaration) -> Bool {
        ([preview] + preview.descendentDeclarations)
            .lazy
            .flatMap(\.references)
            .compactMap { self.graph.declaration(withUsr: $0.usr) }
            .contains { self.graph.isUsed($0) && self.isSwiftUIView($0) }
    }

    /// Whether the type conforms to `View`, directly or through a protocol it conforms to that refines `View`, or a
    /// superclass that conforms.
    private func isSwiftUIView(_ declaration: Declaration) -> Bool {
        guard [.struct, .class, .enum].contains(declaration.kind) else { return false }

        var visited: Set<Declaration> = [declaration]
        var pending = [declaration]

        while let current = pending.popLast() {
            for related in current.related {
                if related.declarationKind == .protocol, related.usr == Self.swiftUIViewUsr {
                    return true
                }

                if let inherited = graph.declaration(withUsr: related.usr), visited.insert(inherited).inserted {
                    pending.append(inherited)
                }
            }
        }

        return false
    }

    private func ignoreUnusedDescendents(in decls: Set<Declaration>, unusedDeclarations: Set<Declaration>) {
        for decl in decls {
            guard !decl.declarations.isEmpty || !decl.unusedParameters.isEmpty
            else { continue }

            if unusedDeclarations.contains(decl) {
                decl.descendentDeclarations.forEach { graph.markIgnored($0) }
            } else {
                ignoreUnusedDescendents(in: decl.declarations,
                                        unusedDeclarations: unusedDeclarations)
            }
        }
    }
}
