import Configuration
import Foundation
import Logger
import Shared

public final class SourceGraph {
    public private(set) var allDeclarations: Set<Declaration> = []
    public private(set) var usedDeclarations: Set<Declaration> = []
    public private(set) var redundantProtocols: [Declaration: (references: Set<Reference>, inherited: Set<Reference>)] = [:]
    public private(set) var rootDeclarations: Set<Declaration> = []
    public private(set) var redundantPublicAccessibility: [Declaration: Set<String>] = [:]
    public private(set) var redundantOpenAccessibility: [Declaration: Set<String>] = [:]
    public private(set) var missingFinalDeclarations: Set<Declaration> = []
    public private(set) var redundantAccessLevel: [Declaration: RedundantAccessLevel] = [:]
    public private(set) var emptyExtensions: Set<Declaration> = []
    public private(set) var rootReferences: Set<Reference> = []
    public private(set) var allReferences: Set<Reference> = []
    public private(set) var retainedDeclarations: Set<Declaration> = []
    public private(set) var ignoredDeclarations: Set<Declaration> = []
    public private(set) var assetReferences: Set<AssetReference> = []
    public private(set) var mainAttributedDeclarations: Set<Declaration> = []
    public private(set) var allReferencesByUsr: [String: Set<Reference>] = [:]
    public private(set) var indexedSourceFiles: [SourceFile] = []
    public private(set) var unusedModuleImports: Set<Declaration> = []
    public private(set) var assignOnlyProperties: Set<Declaration> = []
    public private(set) var suppressedAssignOnlyProperties: Set<Declaration> = []
    public private(set) var unassignedOptionalProperties: Set<Declaration> = []
    public private(set) var extensions: [Declaration: Set<Declaration>] = [:]
    public private(set) var commandIgnoredDeclarations: [Declaration: CommandIgnoreKind] = [:]
    public private(set) var functionsWithIgnoredParameters: Set<Declaration> = []
    public private(set) var platformConditionalNames: Set<String> = []
    public private(set) var parameterAttributeNames: Set<String> = []
    public private(set) var platformConditionalNamesByFile: [SourceFile: Set<String>] = [:]
    public private(set) var usedLocalizedStringKeys: Set<String> = []
    /// Literal prefixes of keys built at runtime and looked up in the calling module's bundle, by module.
    public private(set) var runtimeLocalizedStringKeyPrefixesByModule: [String: Set<String>] = [:]
    /// Literal prefixes of keys built at runtime and looked up in an unknown bundle.
    public private(set) var runtimeLocalizedStringKeyPrefixes: Set<String> = []
    /// Call sites of keys built at runtime without a literal prefix, whose catalogue keys cannot be determined.
    public private(set) var unprefixedRuntimeLocalizedStringKeyLocations: Set<Location> = []
    public private(set) var synthesizedUses: Set<SynthesizedUse> = []
    /// Locations of the property components of key paths that are not the argument of a `keyPath:` subscript.
    public private(set) var keyPathComponentLocations: Set<Location> = []
    public private(set) var unusedAssetCatalogSymbols: [Declaration: AssetCatalogSymbol] = [:]
    /// Strings that may name an asset catalog resource, from string literals, Interface Builder files and
    /// build settings.
    public private(set) var assetCatalogNameReferences: Set<String> = []

    private var indexedModules: Set<String> = []
    private var indexedSystemModules: Set<String> = []
    private var systemModulesByUsr: [String: Set<String>] = [:]
    private var unindexedExportedModules: Set<String> = []
    private var allDeclarationsByKind: [Declaration.Kind: Set<Declaration>] = [:]
    private var allDeclarationsByUsr: [String: Declaration] = [:]
    private var moduleToExportingModules: [String: Set<String>] = [:]
    private var syntheticUsrLocations: [String: [Location]] = [:]

    private let configuration: Configuration
    private let logger: Logger

    public init(configuration: Configuration, logger: Logger) {
        self.configuration = configuration
        self.logger = logger
    }

    public func indexingComplete() {
        rootDeclarations = allDeclarations.filter { $0.parent == nil }
        rootReferences = allReferences.filter { $0.parent == nil }
        unindexedExportedModules = Set(moduleToExportingModules.keys)
            .subtracting(indexedModules)
            .subtracting(indexedSystemModules)
    }

    public var unusedDeclarations: Set<Declaration> {
        allDeclarations.subtracting(usedDeclarations)
    }

    public func declarations(ofKind kind: Declaration.Kind) -> Set<Declaration> {
        allDeclarationsByKind[kind] ?? []
    }

    public func declarations(ofKinds kinds: Set<Declaration.Kind>) -> Set<Declaration> {
        declarations(ofKinds: Array(kinds))
    }

    public func declarations(ofKinds kinds: [Declaration.Kind]) -> Set<Declaration> {
        kinds.flatMapSet { allDeclarationsByKind[$0, default: []] }
    }

    public func declaration(withUsr usr: String) -> Declaration? {
        allDeclarationsByUsr[usr]
    }

    public func references(to decl: Declaration) -> Set<Reference> {
        decl.usrs.flatMapSet { references(to: $0) }
    }

    public func references(to usr: String) -> Set<Reference> {
        allReferencesByUsr[usr, default: []]
    }

    public func hasReferences(to decl: Declaration) -> Bool {
        decl.usrs.contains { !allReferencesByUsr[$0, default: []].isEmpty }
    }

    func markRedundantProtocol(_ declaration: Declaration, references: Set<Reference>, inherited: Set<Reference>) {
        redundantProtocols[declaration] = (references, inherited)
    }

    func markRedundantPublicAccessibility(_ declaration: Declaration, modules: Set<String>) {
        redundantPublicAccessibility[declaration] = modules
    }

    func unmarkRedundantPublicAccessibility(_ declaration: Declaration) {
        _ = redundantPublicAccessibility.removeValue(forKey: declaration)
    }

    func markRedundantOpenAccessibility(_ declaration: Declaration, modules: Set<String>) {
        redundantOpenAccessibility[declaration] = modules
    }

    func markMissingFinal(_ declaration: Declaration) {
        missingFinalDeclarations.insert(declaration)
    }

    func markRedundantAccessLevel(_ declaration: Declaration, accessibility: Accessibility, context: Accessibility?) {
        redundantAccessLevel[declaration] = RedundantAccessLevel(accessibility: accessibility, context: context)
    }

    func markUnusedAssetCatalogSymbol(_ declaration: Declaration, symbol: AssetCatalogSymbol) {
        unusedAssetCatalogSymbols[declaration] = symbol
    }

    func markIgnored(_ declaration: Declaration) {
        _ = ignoredDeclarations.insert(declaration)
    }

    public func markCommandIgnored(_ declaration: Declaration, kind: CommandIgnoreKind) {
        commandIgnoredDeclarations[declaration] = kind
    }

    public func markHasIgnoredParameters(_ declaration: Declaration) {
        _ = functionsWithIgnoredParameters.insert(declaration)
    }

    public func markRetained(_ declaration: Declaration) {
        if let parent = declaration.parent {
            for usr in declaration.usrs {
                let reference = Reference(
                    name: declaration.name,
                    kind: .retained,
                    declarationKind: declaration.kind,
                    usr: usr,
                    location: declaration.location
                )
                reference.parent = parent
                add(reference, from: parent)
            }
        } else {
            _ = retainedDeclarations.insert(declaration)
        }
    }

    func unmarkRetained(_ declaration: Declaration) {
        retainedDeclarations.remove(declaration)

        let retainedReferences = declaration.usrs.flatMapSet { usr in
            allReferencesByUsr[usr, default: []]
        }.filter { reference in
            reference.kind == .retained && reference.parent === declaration.parent
        }

        for reference in retainedReferences {
            remove(reference)
        }
    }

    public func markRetained(_ declarations: Set<Declaration>) {
        declarations.forEach { markRetained($0) }
    }

    func markAssignOnlyProperty(_ declaration: Declaration) {
        _ = assignOnlyProperties.insert(declaration)
    }

    func markSuppressedAssignOnlyProperty(_ declaration: Declaration) {
        _ = suppressedAssignOnlyProperties.insert(declaration)
    }

    func markUnassignedOptionalProperty(_ declaration: Declaration) {
        _ = unassignedOptionalProperties.insert(declaration)
    }

    func markMainAttributed(_ declaration: Declaration) {
        _ = mainAttributedDeclarations.insert(declaration)
    }

    public func isRetained(_ declaration: Declaration) -> Bool {
        retainedDeclarations.contains(declaration) || references(to: declaration).contains { $0.kind == .retained }
    }

    public func add(_ declaration: Declaration) {
        allDeclarations.insert(declaration)
        allDeclarationsByKind[declaration.kind, default: []].insert(declaration)
        for usr in declaration.usrs {
            if let existingDecl = allDeclarationsByUsr[usr] {
                logger.warn("""
                Declaration conflict detected: a declaration with the USR '\(usr)' has already been indexed.
                This issue can cause inconsistent and incorrect results.
                Existing declaration: \(existingDecl), declared in modules: \(existingDecl.location.file.modules.sorted())
                Conflicting declaration: \(declaration), declared in modules: \(declaration.location.file.modules.sorted())
                To resolve this warning, make sure all build modules are uniquely named.
                """)
                // Keep the declaration that sorts first to ensure deterministic results
                // regardless of indexing order.
                if declaration < existingDecl {
                    allDeclarationsByUsr[usr] = declaration
                }
            } else {
                allDeclarationsByUsr[usr] = declaration
            }
        }
    }

    public func add(_ declarations: Set<Declaration>) {
        declarations.forEach { add($0) }
    }

    public func remove(_ declaration: Declaration) {
        declaration.parent?.declarations.remove(declaration)
        allDeclarations.remove(declaration)
        allDeclarationsByKind[declaration.kind]?.remove(declaration)
        rootDeclarations.remove(declaration)
        usedDeclarations.remove(declaration)
        assignOnlyProperties.remove(declaration)
        suppressedAssignOnlyProperties.remove(declaration)
        unassignedOptionalProperties.remove(declaration)
        declaration.usrs.forEach { allDeclarationsByUsr.removeValue(forKey: $0) }
    }

    public func add(_ reference: Reference) {
        _ = allReferences.insert(reference)
        allReferencesByUsr[reference.usr, default: []].insert(reference)
    }

    func addRootReference(_ reference: Reference) {
        rootReferences.insert(reference)
        add(reference)
    }

    public func add(_ references: Set<Reference>) {
        allReferences.formUnion(references)
        references.forEach { allReferencesByUsr[$0.usr, default: []].insert($0) }
    }

    public func add(_ reference: Reference, from declaration: Declaration) {
        if reference.kind == .related {
            _ = declaration.related.insert(reference)
        } else {
            _ = declaration.references.insert(reference)
        }

        add(reference)
    }

    func remove(_ reference: Reference) {
        _ = allReferences.remove(reference)
        allReferences.subtract(reference.descendentReferences)
        allReferencesByUsr[reference.usr]?.remove(reference)

        if let parent = reference.parent {
            parent.references.remove(reference)
            parent.related.remove(reference)
        }
    }

    public func add(_ assetReference: AssetReference) {
        _ = assetReferences.insert(assetReference)
    }

    public func addUsedLocalizedStringKeys(_ keys: Set<String>) {
        usedLocalizedStringKeys.formUnion(keys)
    }

    public func addRuntimeLocalizedStringKeyPrefixes(_ prefixes: Set<String>, modules: Set<String>) {
        for module in modules {
            runtimeLocalizedStringKeyPrefixesByModule[module, default: []].formUnion(prefixes)
        }
    }

    public func addRuntimeLocalizedStringKeyPrefixes(_ prefixes: Set<String>) {
        runtimeLocalizedStringKeyPrefixes.formUnion(prefixes)
    }

    public func addUnprefixedRuntimeLocalizedStringKeyLocations(_ locations: Set<Location>) {
        unprefixedRuntimeLocalizedStringKeyLocations.formUnion(locations)
    }

    public func addAssetCatalogNameReferences(_ names: Set<String>) {
        assetCatalogNameReferences.formUnion(names)
    }

    public func addSynthesizedUses(_ uses: Set<SynthesizedUse>) {
        synthesizedUses.formUnion(uses)
    }

    public func addKeyPathComponentLocations(_ locations: Set<Location>) {
        keyPathComponentLocations.formUnion(locations)
    }

    func markUsed(_ declaration: Declaration) {
        _ = usedDeclarations.insert(declaration)
    }

    func isUsed(_ declaration: Declaration) -> Bool {
        usedDeclarations.contains(declaration)
    }

    func isExternal(_ reference: Reference) -> Bool {
        declaration(withUsr: reference.usr) == nil
    }

    public func addIndexedSourceFile(_ file: SourceFile) {
        indexedSourceFiles.append(file)
    }

    public func addPlatformConditionalNames(_ names: Set<String>, in file: SourceFile) {
        platformConditionalNames.formUnion(names)
        platformConditionalNamesByFile[file, default: []].formUnion(names)
    }

    public func addParameterAttributeNames(_ names: Set<String>) {
        parameterAttributeNames.formUnion(names)
    }

    public func addIndexedModules(_ modules: Set<String>) {
        indexedModules.formUnion(modules)
    }

    public func isModuleIndexed(_ module: String) -> Bool {
        indexedModules.contains(module)
    }

    public func addExportedModule(_ module: String, exportedBy exportingModules: Set<String>) {
        moduleToExportingModules[module, default: []].formUnion(exportingModules)
    }

    public func moduleExportsUnindexedModules(_ module: String) -> Bool {
        unindexedExportedModules.contains { unindexedModule in
            isModule(unindexedModule, exportedBy: module)
        }
    }

    public func isModule(_ module: String, exportedBy exportingModule: String) -> Bool {
        // Walk the modules exporting `module`, directly or transitively. System modules can export each other
        // (a Swift overlay and its Clang module share a name), so visited modules are tracked.
        var visited: Set<String> = [module]
        var pending = [module]

        while let current = pending.popLast() {
            for exporter in moduleToExportingModules[current, default: []] {
                if exporter == exportingModule {
                    return true
                }

                if visited.insert(exporter).inserted {
                    pending.append(exporter)
                }
            }
        }

        return false
    }

    /// Records the system modules found in the index store, the modules each of them may export, and the system
    /// modules declaring the given external USRs.
    public func addSystemModules(
        _ modules: Set<String>,
        exports: [String: Set<String>],
        modulesByUsr: [String: Set<String>]
    ) {
        indexedSystemModules.formUnion(modules)

        for (module, exportedModules) in exports.merging(SystemModuleExports.known, uniquingKeysWith: { $0.union($1) }) {
            for exportedModule in exportedModules
                where exportedModule != module && !SystemModuleExports.implicitlyImported.contains(exportedModule)
            {
                moduleToExportingModules[exportedModule, default: []].insert(module)
            }
        }

        for (usr, usrModules) in modulesByUsr {
            systemModulesByUsr[usr, default: []].formUnion(usrModules)
        }
    }

    public func isSystemModuleIndexed(_ module: String) -> Bool {
        indexedSystemModules.contains(module)
    }

    /// The system modules that may declare the given USR, or `nil` when none is known.
    public func systemModules(forUsr usr: String) -> Set<String>? {
        let modules = systemModulesByUsr[usr, default: []].union(SystemModuleUsr.modules(in: usr))
        return modules.isEmpty ? nil : modules
    }

    func markUnusedModuleImport(_ statement: ImportStatement) {
        let file = statement.location.file.path
        let id = SyntheticUsr.moduleImport(statement.module, in: file, projectRoot: configuration.projectRoot)
        guard let usr = numberedSyntheticUsr(id, at: statement.location) else { return }

        let decl = Declaration(name: statement.module, kind: .module, usrs: [usr], location: statement.location)
        unusedModuleImports.insert(decl)
    }

    /// Empty extensions are absent from the index store, so they are recorded from the syntax tree.
    public func markEmptyExtension(extendedTypeName: String, location: Location) {
        let id = SyntheticUsr.emptyExtension(of: extendedTypeName, in: location.file.path, projectRoot: configuration.projectRoot)
        guard let usr = numberedSyntheticUsr(id, at: location) else { return }

        let decl = Declaration(name: extendedTypeName, kind: .extension, usrs: [usr], location: location)
        emptyExtensions.insert(decl)
    }

    /// Results of one kind that share a file, such as two empty extensions of one type, share their base id. They are
    /// numbered in the order they are marked, which is source order within a file. A location that is already marked,
    /// as when a file belongs to several targets, yields `nil`.
    private func numberedSyntheticUsr(_ id: String, at location: Location) -> String? {
        var locations = syntheticUsrLocations[id, default: []]
        guard !locations.contains(location) else { return nil }

        locations.append(location)
        syntheticUsrLocations[id] = locations
        return SyntheticUsr.numbered(id, occurrence: locations.count)
    }

    func markExtension(_ extensionDecl: Declaration, extending extendedDecl: Declaration) {
        _ = extensions[extendedDecl, default: []].insert(extensionDecl)
    }

    func inheritedTypeReferences(of decl: Declaration, seenDeclarations: Set<Declaration> = []) -> Set<Reference> {
        var references = Set<Reference>()

        for reference in decl.immediateInheritedTypeReferences {
            references.insert(reference)

            if let inheritedDecl = declaration(withUsr: reference.usr) {
                // Detect circular references. The following is valid Swift.
                // class SomeClass {}
                // extension SomeClass: SomeProtocol {}
                // protocol SomeProtocol: SomeClass {}
                guard !seenDeclarations.contains(inheritedDecl) else { continue }

                references = inheritedTypeReferences(of: inheritedDecl, seenDeclarations: seenDeclarations.union([decl])).union(references)
            }
        }

        return references
    }

    func inheritedDeclarations(of decl: Declaration) -> [Declaration] {
        inheritedTypeReferences(of: decl).compactMap { declaration(withUsr: $0.usr) }
    }

    func immediateSubclasses(of decl: Declaration) -> Set<Declaration> {
        references(to: decl)
            .filter { $0.kind == .related && $0.declarationKind == .class }
            .flatMap { $0.parent?.usrs ?? [] }
            .compactMapSet { declaration(withUsr: $0) }
    }

    func subclasses(of decl: Declaration) -> Set<Declaration> {
        let immediate = immediateSubclasses(of: decl)
        let allSubclasses = immediate.flatMapSet { subclasses(of: $0) }
        return immediate.union(allSubclasses)
    }

    func extendedDeclarationReference(forExtension extensionDeclaration: Declaration) throws -> Reference? {
        guard let extendedKind = extensionDeclaration.kind.extendedKind else {
            throw PeripheryError.sourceGraphIntegrityError(message: "Unknown extended reference kind for extension '\(extensionDeclaration.kind.rawValue)'")
        }

        return extensionDeclaration.references
            .filter { $0.declarationKind == extendedKind && $0.name == extensionDeclaration.name }
            .min()
    }

    func extendedDeclaration(forExtension extensionDeclaration: Declaration) throws -> Declaration? {
        guard let extendedReference = try extendedDeclarationReference(forExtension: extensionDeclaration) else { return nil }

        if let extendedDeclaration = declaration(withUsr: extendedReference.usr) {
            return extendedDeclaration
        }

        return nil
    }

    func allSuperDeclarationsInOverrideChain(from decl: Declaration) -> Set<Declaration> {
        guard decl.isOverride else { return [] }

        let overridenDecl = decl.related
            .filter { $0.declarationKind == decl.kind && $0.name == decl.name }
            .compactMap { declaration(withUsr: $0.usr) }
            .min()

        guard let overridenDecl else {
            return []
        }

        return Set([overridenDecl]).union(allSuperDeclarationsInOverrideChain(from: overridenDecl))
    }

    func baseDeclaration(fromOverride decl: Declaration) -> (Declaration, Bool) {
        guard decl.isOverride else { return (decl, true) }

        let baseDecl = references(to: decl)
            .filter {
                $0.kind == .related &&
                    $0.declarationKind == decl.kind &&
                    $0.name == decl.name
            }
            .compactMap(\.parent)
            .min()

        guard let baseDecl else {
            // Base reference is external, return the current function as it's the closest.
            return (decl, false)
        }

        return baseDeclaration(fromOverride: baseDecl)
    }

    func allOverrideDeclarations(fromBase decl: Declaration) -> Set<Declaration> {
        decl.relatedEquivalentReferences
            .compactMap { declaration(withUsr: $0.usr) }
            .reduce(into: .init()) { result, decl in
                guard decl.isOverride else { return }

                result.insert(decl)
                result.formUnion(allOverrideDeclarations(fromBase: decl))
            }
    }

    func isCodable(_ decl: Declaration) -> Bool {
        let codableTypes = ["Codable", "Decodable", "Encodable"] + configuration.externalEncodableProtocols + configuration.externalCodableProtocols

        return inheritedTypeReferences(of: decl).contains {
            [.protocol, .typealias].contains($0.declarationKind) && codableTypes.contains($0.name)
        }
    }

    func isEncodable(_ decl: Declaration) -> Bool {
        let encodableTypes = ["Encodable"] + configuration.externalEncodableProtocols + configuration.externalCodableProtocols

        return inheritedTypeReferences(of: decl).contains {
            [.protocol, .typealias].contains($0.declarationKind) && encodableTypes.contains($0.name)
        }
    }

    func isEquatable(_ decl: Declaration) -> Bool {
        let equatableTypes = ["Equatable", "Hashable"]

        return inheritedTypeReferences(of: decl).contains {
            [.protocol, .typealias].contains($0.declarationKind) && equatableTypes.contains($0.name)
        }
    }

    func isHashable(_ decl: Declaration) -> Bool {
        inheritedTypeReferences(of: decl).contains {
            [.protocol, .typealias].contains($0.declarationKind) && $0.name == "Hashable"
        }
    }
}
