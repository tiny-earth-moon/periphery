extension SourceFile {
    /// Whether the file belongs to a module other than `declaringModules` and does not `@testable import` any of them:
    /// such a file needs `public` to use a declaration of those modules, and `open` to subclass or override it.
    func isNonTestableClient(ofModules declaringModules: Set<String>) -> Bool {
        guard !modules.isSubset(of: declaringModules) else { return false }

        return !importStatements.contains { $0.isTestable && declaringModules.contains($0.module) }
    }
}
