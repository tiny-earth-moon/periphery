import Configuration
import Foundation
import Shared

final class UsedDeclarationMarker: SourceGraphMutator {
    private static let previewableProtocolUsrs: Set<String> = [
        "s:7SwiftUI4ViewP",
        "s:7SwiftUI6WidgetP",
        "s:7SwiftUI13ControlWidgetP",
    ]
    private static let previewProviderUsr = "s:7SwiftUI15PreviewProviderP"

    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        removeErroneousProtocolReferences()

        if graph.recordsExplanations {
            markUsedRecordingPredecessors(from: rootsWithPredecessors())
        } else {
            markUsed(graph.retainedDeclarations)
            markUsed(graph.rootReferences.compactMapSet { graph.declaration(withUsr: $0.usr) })
        }

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
            graph.remove(reference, discardedBy: Self.self, detail: "protocol requirement to a conforming declaration whose enclosing declaration is unreferenced")
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
                    graph.recordUsePredecessor(.reference(reference, from: declaration), for: referenced)
                    pending.append(referenced)
                }
            }
        }
    }

    /// The retained declarations and the declarations referenced from top-level code, sorted so that the recorded
    /// chains do not depend on set order.
    private func rootsWithPredecessors() -> [(Declaration, UsePredecessor)] {
        let retained = graph.retainedDeclarations.sorted().map { ($0, UsePredecessor.retained) }
        let referenced = graph.rootReferences
            .sorted { $0.location < $1.location }
            .compactMap { reference in
                graph.declaration(withUsr: reference.usr).map { ($0, UsePredecessor.rootReference(reference)) }
            }
        return retained + referenced
    }

    /// The same walk as `markUsed(_:)`, breadth-first, recording the predecessor of each declaration so that
    /// `--explain` can print a shortest reference chain from a root. Only used when explanations are recorded.
    private func markUsedRecordingPredecessors(from roots: [(Declaration, UsePredecessor)]) {
        var queue: [Declaration] = []
        var head = 0

        for (declaration, predecessor) in roots {
            graph.recordUsePredecessor(predecessor, for: declaration)
            queue.append(declaration)
        }

        while head < queue.count {
            let declaration = queue[head]
            head += 1
            guard !graph.isUsed(declaration) else { continue }

            graph.markUsed(declaration)

            let references = [declaration.references, declaration.related].joined().sorted { $0.location < $1.location }
            for reference in references {
                if let referenced = graph.declaration(withUsr: reference.usr), !graph.isUsed(referenced) {
                    graph.recordUsePredecessor(.reference(reference, from: declaration), for: referenced)
                    queue.append(referenced)
                }
            }
        }
    }

    /// Marks used each `#Preview` expansion and each `PreviewProvider` that previews a used SwiftUI view or widget,
    /// along with the code it references. Previews that only reference unused code stay unused.
    private func markLivePreviewExpansionsUsed() {
        var pendingPreviews = graph.references(to: SwiftUIRetainer.previewRegistryUsr)
            .compactMap(\.parent)
            .filter { $0.isImplicit && !graph.isUsed($0) }
            .mapSet { $0 }
        pendingPreviews.formUnion(graph.declarations(ofKinds: [.class, .struct, .enum]).filter {
            !graph.isUsed($0) && isPreviewProvider($0)
        })

        while true {
            let livePreviews = pendingPreviews.filter(previewsUsedView)
            guard !livePreviews.isEmpty else { break }

            pendingPreviews.subtract(livePreviews)
            let previewDeclarations = livePreviews.flatMapSet { $0.descendentDeclarations.union([$0]) }
            previewDeclarations.forEach { graph.recordUsePredecessor(.livePreview, for: $0) }
            markUsed(previewDeclarations)
        }
    }

    private func previewsUsedView(_ preview: Declaration) -> Bool {
        ([preview] + preview.descendentDeclarations)
            .lazy
            .flatMap(\.references)
            .compactMap { self.graph.declaration(withUsr: $0.usr) }
            .contains { self.graph.isUsed($0) && self.isPreviewable($0) }
    }

    /// Whether the type conforms to a previewable protocol (`View`, `Widget` or `ControlWidget`), directly, through a
    /// protocol it conforms to that refines one, or through a superclass that conforms.
    private func isPreviewable(_ declaration: Declaration) -> Bool {
        guard [.struct, .class, .enum].contains(declaration.kind) else { return false }

        var visited: Set<Declaration> = [declaration]
        var pending = [declaration]

        while let current = pending.popLast() {
            for related in current.related {
                if related.declarationKind == .protocol, Self.previewableProtocolUsrs.contains(related.usr) {
                    return true
                }

                if let inherited = graph.declaration(withUsr: related.usr), visited.insert(inherited).inserted {
                    pending.append(inherited)
                }
            }
        }

        return false
    }

    private func isPreviewProvider(_ declaration: Declaration) -> Bool {
        declaration.related.contains {
            $0.declarationKind == .protocol && $0.usr == Self.previewProviderUsr
        }
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
