import SwiftSyntax

extension ExprSyntax {
    /// The token that names the function called by a call expression whose called expression is `self`: `f` in
    /// `f()`, `a.f()` and `f<T>()`, or `nil` when the callee has no name.
    var calleeNameToken: TokenSyntax? {
        if let reference = self.as(DeclReferenceExprSyntax.self) {
            return reference.baseName
        }

        if let memberAccess = self.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName
        }

        if let specialization = self.as(GenericSpecializationExprSyntax.self) {
            return specialization.expression.calleeNameToken
        }

        return nil
    }
}
