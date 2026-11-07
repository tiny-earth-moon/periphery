import Foundation

extension SourceGraph {
    /// Retains the declaration and each of its ancestors, so that a declaration discovered by a framework at
    /// runtime is not hidden as an ignored descendant of an enclosing namespace that appears unused.
    func markRetainedWithAncestors(_ declaration: Declaration, reason: @autoclosure () -> RetentionReason) {
        markRetained(declaration, reason: reason())

        for ancestralDeclaration in declaration.ancestralDeclarations {
            markRetained(ancestralDeclaration, reason: reason())
        }
    }
}
