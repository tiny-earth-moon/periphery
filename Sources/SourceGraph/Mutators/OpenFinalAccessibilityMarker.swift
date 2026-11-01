import Configuration
import Shared

/// Identifies `open` declarations that are never subclassed or overridden outside their module, and classes or
/// members that are never subclassed or overridden at all and could therefore be `final`.
///
/// Subclasses and overrides are read from the related references of the index. The index only describes the
/// scanned modules, so an `open` declaration subclassed or overridden by an unscanned client module cannot be
/// observed; the analysis is therefore opt-in and disabled for `open` declarations when `retain_public` is set.
final class OpenFinalAccessibilityMarker: SourceGraphMutator {
    private static let overridableMemberKinds: Set<Declaration.Kind> = [
        .functionMethodInstance, .functionMethodClass, .functionSubscript, .varInstance, .varClass,
    ]

    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() throws {
        guard configuration.enableOpenFinalAnalysis else { return }

        for classDecl in graph.declarations(ofKind: .class) where !classDecl.isImplicit && !classDecl.isActor {
            validateRedundantOpen(classDecl)
            validateMissingFinal(classDecl)
        }
    }

    // MARK: - Redundant open

    private func validateRedundantOpen(_ classDecl: Declaration) {
        let isOpenClass = classDecl.accessibility.isExplicitly(.open)

        if isOpenClass, !configuration.retainPublic, !isSubclassedCrossModule(classDecl) {
            graph.markRedundantOpenAccessibility(classDecl, modules: classDecl.location.file.modules)
        }

        for member in classDecl.declarations where isCandidateMember(member) && member.accessibility.isExplicitly(.open) {
            // An open member of a class that is not open cannot be overridden outside of its module.
            if !isOpenClass || (!configuration.retainPublic && !isOverriddenCrossModule(member)) {
                graph.markRedundantOpenAccessibility(member, modules: member.location.file.modules)
            }
        }
    }

    // MARK: - Missing final

    private func validateMissingFinal(_ classDecl: Declaration) {
        guard !isFinal(classDecl), !isDynamicallyExposed(classDecl) else { return }

        if [.public, .internal].contains(classDecl.accessibility.value), subclassDeclarations(of: classDecl).isEmpty {
            // Members of a class that could be final are implicitly final once the class is.
            graph.markMissingFinal(classDecl)
            return
        }

        for member in classDecl.declarations where isCandidateMember(member) {
            guard [.public, .internal].contains(member.accessibility.value),
                  !isFinal(member),
                  !isDynamicallyExposed(member),
                  overrideDeclarations(of: member).isEmpty
            else { continue }

            graph.markMissingFinal(member)
        }
    }

    // MARK: - Index relations

    /// Classes and class-constrained protocols that inherit from the given class.
    private func subclassDeclarations(of classDecl: Declaration) -> Set<Declaration> {
        graph.references(to: classDecl).compactMapSet { ref -> Declaration? in
            guard ref.kind == .related,
                  let parent = ref.parent,
                  parent != classDecl,
                  [.class, .protocol].contains(parent.kind)
            else { return nil }

            return parent
        }
    }

    /// Overrides of the given member, in any subclass of its class.
    private func overrideDeclarations(of member: Declaration) -> Set<Declaration> {
        guard let classDecl = member.parent else { return [] }

        let subclasses = graph.subclasses(of: classDecl)
        let referencingDecls = graph.references(to: member)
            .filter { $0.kind == .related && $0.declarationKind == member.kind && $0.name == member.name }
            .compactMapSet(\.parent)
        let relatedDecls = member.relatedEquivalentReferences.compactMapSet { graph.declaration(withUsr: $0.usr) }

        return referencingDecls.union(relatedDecls).filter { decl in
            guard decl != member, decl.isOverride, let declParent = decl.parent else { return false }

            return subclasses.contains(declParent)
        }
    }

    private func isSubclassedCrossModule(_ classDecl: Declaration) -> Bool {
        subclassDeclarations(of: classDecl).contains { isDeclaredInNonTestableForeignModule($0, relativeTo: classDecl) }
    }

    private func isOverriddenCrossModule(_ member: Declaration) -> Bool {
        overrideDeclarations(of: member).contains { isDeclaredInNonTestableForeignModule($0, relativeTo: member) }
    }

    /// Whether `decl` is declared outside the module of `base`, in a file that does not `@testable import` it: a
    /// testable import can subclass or override a `public` declaration, which therefore needs no `open`.
    private func isDeclaredInNonTestableForeignModule(_ decl: Declaration, relativeTo base: Declaration) -> Bool {
        let baseModules = base.location.file.modules
        let file = decl.location.file

        guard !file.modules.subtracting(baseModules).isEmpty else { return false }

        return !file.importStatements.contains { $0.isTestable && baseModules.contains($0.module) }
    }

    // MARK: - Predicates

    private func isCandidateMember(_ decl: Declaration) -> Bool {
        Self.overridableMemberKinds.contains(decl.kind) && !decl.isImplicit && !decl.isConstant
    }

    private func isFinal(_ decl: Declaration) -> Bool {
        decl.modifiers.contains("final")
    }

    private func isDynamicallyExposed(_ decl: Declaration) -> Bool {
        decl.modifiers.contains("dynamic") || (configuration.retainObjcAccessible && decl.isObjcAccessible)
    }
}
