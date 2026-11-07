import Foundation

extension SourceGraph {
    /// Retains the declaration and each of its ancestors, so that a declaration discovered by a framework at
    /// runtime is not hidden as an ignored descendant of an enclosing namespace that appears unused.
    func markRetainedWithAncestors(_ declaration: Declaration, reason: @autoclosure () -> RetentionReason) {
        markRetainedWithAncestors(declaration, reason: reason(), ancestorReason: reason())
    }

    /// Retains the declaration for `reason` and each of its ancestors for `ancestorReason`.
    func markRetainedWithAncestors(
        _ declaration: Declaration,
        reason: @autoclosure () -> RetentionReason,
        ancestorReason: @autoclosure () -> RetentionReason
    ) {
        markRetained(declaration, reason: reason())

        for ancestralDeclaration in declaration.ancestralDeclarations {
            markRetained(ancestralDeclaration, reason: ancestorReason())
        }
    }
}
