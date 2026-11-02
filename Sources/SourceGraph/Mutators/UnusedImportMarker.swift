import Configuration
import Foundation
import Shared

/// Marks unused import statements (experimental).
///
/// A module import is unused when the source file contains no references to it, and no other
/// imported modules either export it, or extend declarations declared by it.
final class UnusedImportMarker: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration
    private let retainedModules: Set<String>
    private let analysesSystemImports: Bool

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
        retainedModules = Set(configuration.retainUnusedImportedModules)
        analysesSystemImports = configuration.enableUnusedSystemImports
    }

    func mutate() throws {
        guard !configuration.disableUnusedImportAnalysis else { return }

        var referencedModulesByFile = graph.indexedSourceFiles.reduce(into: [SourceFile: Set<String>]()) { result, file in
            result[file] = []
        }
        var moduleCache: [String: Set<String>] = [:]
        // References whose declaring module is unknown, with system import analysis enabled.
        var unresolvedUsrs: Set<String> = []
        // Files referencing a declaration of unknown module, whose system imports are not analysed.
        var filesWithUnresolvedReferences: Set<SourceFile> = []

        // Build a mapping of source files and the modules they reference.
        for ref in graph.allReferences {
            if let modules = moduleCache[ref.usr] {
                referencedModulesByFile[ref.location.file, default: []].formUnion(modules)
                if unresolvedUsrs.contains(ref.usr) {
                    filesWithUnresolvedReferences.insert(ref.location.file)
                }
                continue
            }

            var directModules: Set<String> = []
            var indirectModules: Set<String> = []
            var isUnresolved = false

            if let decl = graph.declaration(withUsr: ref.usr) {
                directModules = decl.location.file.modules
                let indirectRefs = referencedTypes(from: decl)

                indirectModules = indirectRefs
                    .flatMapSet { indirectRef -> Set<String> in
                        if let indirectDecl = graph.declaration(withUsr: indirectRef.usr) {
                            return indirectDecl.location.file.modules
                        }

                        guard analysesSystemImports else { return [] }
                        guard let systemModules = graph.systemModules(forUsr: indirectRef.usr) else {
                            isUnresolved = true
                            return []
                        }

                        return systemModules
                    }
                    .union(indirectRefs.flatMapSet { modulesExtending($0) })

                if decl.isOverride {
                    let overrideModules = graph.allSuperDeclarationsInOverrideChain(from: decl)
                        .flatMapSet(\.location.file.modules)
                    indirectModules.formUnion(overrideModules)
                }
            } else if analysesSystemImports, ref.declarationKind != .module {
                if let systemModules = graph.systemModules(forUsr: ref.usr) {
                    directModules = systemModules
                } else {
                    isUnresolved = true
                }
            }

            if isUnresolved {
                unresolvedUsrs.insert(ref.usr)
                filesWithUnresolvedReferences.insert(ref.location.file)
            }

            let referencedModules = directModules
                .union(indirectModules)
                .union(modulesExtending(ref))
            moduleCache[ref.usr] = referencedModules
            referencedModulesByFile[ref.location.file, default: []].formUnion(referencedModules)
        }

        // The index store lacks the references made from the platform conditional branches that were not
        // built. A name written there is attributed to the modules declaring it, and a name that no scanned
        // declaration or import accounts for may come from any system module.
        var filesWithUnresolvedPlatformNames: Set<SourceFile> = []

        if !graph.platformConditionalNamesByFile.isEmpty {
            let modulesByDeclarationName = modulesByDeclarationBaseName()

            for (file, names) in graph.platformConditionalNamesByFile {
                for name in names {
                    if let modules = modulesByDeclarationName[name] {
                        referencedModulesByFile[file, default: []].formUnion(modules)
                    } else if file.importStatements.contains(where: { $0.module == name }) {
                        referencedModulesByFile[file, default: []].insert(name)
                    } else {
                        filesWithUnresolvedPlatformNames.insert(file)
                    }
                }
            }
        }

        func analysesSystemModule(_ module: String, in file: SourceFile) -> Bool {
            analysesSystemImports &&
                graph.isSystemModuleIndexed(module) &&
                !filesWithUnresolvedReferences.contains(file) &&
                !filesWithUnresolvedPlatformNames.contains(file)
        }

        // For each source file, determine whether its imports are unused.
        for (file, referencedModules) in referencedModulesByFile {
            // Ignore retained files and generated asset symbols.
            if configuration.retainFilesMatchers.anyMatch(filename: file.path.string)
                || configuration.isAnalyzedGeneratedAssetSymbolsFile(file.path)
            {
                continue
            }

            let unreferencedImports = file.importStatements
                .filter {
                    // Exclude conditional imports as they may provide symbols for sections of code
                    // that are also conditionally compiled.
                    !$0.isConditional &&
                        // Exclude ignore commented imports
                        !$0.commentCommands.contains(.ignore) &&
                        // Exclude exported/public imports because even though they may be unreferenced
                        // in the current file, their exported symbols may be referenced in others.
                        !$0.isExported &&
                        // Exclude explicitly retained modules.
                        !retainedModules.contains($0.module) &&
                        // Only Consider modules that have been indexed as we need to see which modules
                        // they export. System modules are only considered when every referenced declaration
                        // of the file has a known module.
                        (graph.isModuleIndexed($0.module) || analysesSystemModule($0.module, in: file)) &&
                        !referencedModules.contains($0.module) &&
                        !graph.moduleExportsUnindexedModules($0.module)
                }

            for unreferencedImport in unreferencedImports {
                // In the simple case, a module is unused if it's not referenced. However, it's
                // possible the module exports other referenced modules.
                guard !referencedModules.contains(where: {
                    graph.isModule($0, exportedBy: unreferencedImport.module)
                }) else { continue }

                graph.markUnusedModuleImport(unreferencedImport)
            }
        }
    }

    // MARK: - Private

    /// The modules declaring a referenceable declaration, by the base name of the declaration.
    private func modulesByDeclarationBaseName() -> [String: Set<String>] {
        graph.allDeclarations.reduce(into: [:]) { result, decl in
            guard !PlatformConditionalRetainer.nonReferenceableKinds.contains(decl.kind) else { return }

            result[PlatformConditionalRetainer.baseName(of: decl.name), default: []]
                .formUnion(decl.location.file.modules)
        }
    }

    private var extendedDeclCache: [String: Set<String>] = [:]

    /// Identifies any modules that extend the given declaration reference, as they may provide
    /// members and conformances that are required for compilation.
    private func modulesExtending(_ ref: Reference) -> Set<String> {
        guard ref.declarationKind.isExtendableKind else { return [] }

        if let modules = extendedDeclCache[ref.usr] {
            return modules
        }

        let modules: Set<String> = graph.references(to: ref.usr)
            .flatMapSet {
                guard let parent = $0.parent,
                      parent.kind == ref.declarationKind.extensionKind,
                      parent.name == ref.name
                else { return [] }

                return parent.location.file.modules
            }
        extendedDeclCache[ref.usr] = modules
        return modules
    }

    /// Identifies types referenced by a declaration whose module must be imported for compilation.
    private func referencedTypes(from decl: Declaration) -> Set<Reference> {
        let references: Set<Reference>

        if decl.kind.isVariableKind {
            references = decl.references.filter { $0.role == .varType }
        } else if decl.kind == .enumelement {
            references = decl.references
        } else if decl.kind == .typealias {
            let transitiveReferences = decl.references.flatMapSet { ref -> Set<Reference> in
                guard let refDecl = graph.declaration(withUsr: ref.usr) else { return [] }

                return referencedTypes(from: refDecl)
            }
            references = decl.references.union(transitiveReferences)
        } else if decl.kind.isFunctionKind {
            references = decl.references
                .filter {
                    [
                        .returnType,
                        .parameterType,
                    ].contains($0.role)
                }
        } else if decl.kind == .protocol {
            references = decl.related.filter { $0.role == .refinedProtocolType }
        } else {
            references = []
        }

        return references
    }
}
