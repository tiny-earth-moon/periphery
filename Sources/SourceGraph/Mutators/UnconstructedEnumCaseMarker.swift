import Configuration
import Foundation
import Shared
import SwiftParser
import SwiftSyntax
import SystemPackage

/// Marks enum cases that are only matched in patterns and never constructed: no value of such a case can exist, so
/// the case and the branches that match it are dead.
///
/// The index store does not tell a pattern from a construction, so the indexer walks every source file with
/// `EnumCasePatternCollector`, and every reference must sit at a name it found at a pattern position.
/// Any other reference, in whatever expression, counts as a construction. A false positive would make users delete
/// live code, so every enum whose cases may be produced without a visible construction is skipped:
/// - raw representable, `CaseIterable`, `Codable`/`Decodable` and `CodingKey` enums, and `@objc` enums;
/// - enums conforming to a protocol that is not indexed (other than a few protocols without static requirements),
///   or to an indexed protocol with a static requirement named like the case;
/// - enums with a custom attribute (a macro may construct cases in code the index does not see);
/// - public enums whose public declarations are retained (`retain_public`, `retain_public_modules`);
/// - enums a custom `~=` operator may receive, as `~=` builds the value of an expression pattern;
/// - cases whose name is written in an `#if` clause, which may construct them in code that was not compiled, or in a
///   file left out by `index_exclude`;
/// - enums of a module that expands a macro other than a few known ones, whose expansion the index does not see (and
///   every public enum when any module does).
final class UnconstructedEnumCaseMarker: SourceGraphMutator {
    /// External protocols that have no static requirement a case could satisfy.
    private static let safeExternalProtocols: Set<String> = [
        "BitwiseCopyable", "Comparable", "Copyable", "CustomDebugStringConvertible", "CustomStringConvertible",
        "Equatable", "Error", "Escapable", "Hashable", "Identifiable", "LocalizedError", "Sendable", "SendableMetatype",
    ]
    private static let dynamicCaseProtocols: Set<String> = ["CaseIterable", "RawRepresentable", "CodingKey"]
    private static let staticMemberKinds: Set<Declaration.Kind> = [.varStatic, .varClass, .functionMethodStatic, .functionMethodClass]
    /// Macros whose expansion constructs no enum case of the project.
    private static let knownMacros: Set<String> = [
        "Observable", "ObservationTracked", "ObservationIgnored", "Model", "Attribute", "Relationship", "Transient", "Unique",
        "Index", "Preview", "Previewable", "Entry", "Test", "Suite", "expect", "require", "warning", "error", "externalMacro",
        "fileID", "filePath", "file", "line", "column", "function", "dsohandle", "isolation",
    ]

    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        guard configuration.enableUnconstructedEnumCaseAnalysis,
              let enumsReceivedByPatternOperators = enumsReceivedByPatternOperators()
        else { return }

        let macroModules = modulesExpandingUnknownMacros()
        let candidates = graph.declarations(ofKind: .enum)
            .filter { !enumsReceivedByPatternOperators.contains($0) && !isExcluded($0) && !mayBeConstructedByMacro($0, macroModules: macroModules) }
            .flatMap { enumDeclaration in
                let staticRequirementNames = staticRequirementNames(of: enumDeclaration)
                return enumDeclaration.declarations.filter {
                    $0.kind == .enumelement && !staticRequirementNames.contains(Self.baseName(of: $0.name)) && isCandidate($0)
                }
            }

        guard !candidates.isEmpty else { return }

        let referencesByCase = candidates.reduce(into: [Declaration: Set<Reference>]()) {
            $0[$1] = graph.references(to: $1)
        }
        // A file left out by `index_exclude` that cannot be read may construct a case outside the index.
        guard let index = PatternIndex(
            indexExcludedFiles: graph.indexExcludedSourceFiles.filter { $0.extension == "swift" },
            enumsReceivedByPatternOperators: enumsReceivedByPatternOperators,
            enumElementReferences: Dictionary(grouping: graph.allReferences.filter { $0.declarationKind == .enumelement }, by: \.location),
            graph: graph
        ) else { return }

        for (enumCase, references) in referencesByCase {
            guard !index.namesOutsideTheIndex.contains(Self.baseName(of: enumCase.name)) else { continue }

            let isOnlyMatched = references.allSatisfy {
                $0.kind == .normal && index.isPattern($0.location, hasAssociatedValues: Self.hasAssociatedValues(enumCase))
            }

            if isOnlyMatched {
                graph.markUnconstructedEnumCase(enumCase)
            }
        }
    }

    // MARK: - Private

    private func isCandidate(_ enumCase: Declaration) -> Bool {
        !enumCase.isImplicit &&
            enumCase.related.isEmpty &&
            enumCase.attributes.isEmpty &&
            !graph.isRetained(enumCase) &&
            !graph.references(to: enumCase).isEmpty
    }

    private func isExcluded(_ enumDeclaration: Declaration) -> Bool {
        if enumDeclaration.isImplicit || enumDeclaration.isObjcAccessible || graph.isRetained(enumDeclaration) {
            return true
        }

        if enumDeclaration.attributes.contains(where: { $0.name == "objc" || $0.name.first?.isUppercase == true }) {
            return true
        }

        if [.public, .open].contains(enumDeclaration.accessibility.value),
           configuration.retainsPublicDeclarations(inModules: enumDeclaration.location.file.modules)
        {
            return true
        }

        if graph.isCodable(enumDeclaration) || isRawRepresentable(enumDeclaration) {
            return true
        }

        return graph.inheritedTypeReferences(of: enumDeclaration).contains { reference in
            guard reference.declarationKind == .protocol else { return true }

            if Self.dynamicCaseProtocols.contains(reference.name) {
                return true
            }

            return graph.declaration(withUsr: reference.usr) == nil && !Self.safeExternalProtocols.contains(reference.name)
        }
    }

    /// The modules referencing a macro that is not known to construct no case.
    private func modulesExpandingUnknownMacros() -> Set<String> {
        graph.allReferences
            .filter { $0.declarationKind == .macro && !Self.knownMacros.contains(Self.baseName(of: $0.name)) }
            .flatMapSet(\.location.file.modules)
    }

    private func mayBeConstructedByMacro(_ enumDeclaration: Declaration, macroModules: Set<String>) -> Bool {
        guard !macroModules.isEmpty else { return false }

        return enumDeclaration.accessibility.isAccessibleCrossModule || !enumDeclaration.location.file.modules.isDisjoint(with: macroModules)
    }

    private func isRawRepresentable(_ enumDeclaration: Declaration) -> Bool {
        // A raw type is a related struct, or a reference to a typealias.
        if enumDeclaration.related.contains(where: { $0.declarationKind != .protocol }) ||
            enumDeclaration.immediateInheritedTypeReferences.contains(where: { $0.declarationKind == .typealias })
        {
            return true
        }

        return enumDeclaration.declarations.contains { ["rawValue", "init(rawValue:)"].contains($0.name) }
    }

    /// The names of the static requirements of the indexed protocols the enum conforms to: a case may satisfy them.
    private func staticRequirementNames(of enumDeclaration: Declaration) -> Set<String> {
        graph.inheritedDeclarations(of: enumDeclaration)
            .filter { $0.kind == .protocol }
            .flatMapSet { $0.declarations }
            .filter { Self.staticMemberKinds.contains($0.kind) }
            .mapSet { Self.baseName(of: $0.name) }
    }

    /// The enums an indexed `~=` operator may receive, or `nil` when one may receive any enum (generic, protocol or
    /// typealias parameters, or a requirement or extension of a protocol).
    private func enumsReceivedByPatternOperators() -> Set<Declaration>? {
        var enums = Set<Declaration>()

        for patternOperator in graph.allDeclarations where patternOperator.kind.isFunctionKind && patternOperator.name.hasPrefix("~=(") {
            let declarations = patternOperator.descendentDeclarations.union([patternOperator])

            if let parent = patternOperator.parent {
                if [.protocol, .extensionProtocol].contains(parent.kind) {
                    return nil
                }
                if parent.kind == .enum {
                    enums.insert(parent)
                }
            }

            if declarations.contains(where: { $0.kind == .genericTypeParam }) {
                return nil
            }

            for reference in declarations.flatMapSet(\.references) {
                if [.protocol, .typealias, .associatedtype, .genericTypeParam].contains(reference.declarationKind) {
                    return nil
                }
                if reference.declarationKind == .enum, let enumDeclaration = graph.declaration(withUsr: reference.usr) {
                    enums.insert(enumDeclaration)
                }
            }
        }

        return enums
    }

    private static func baseName(of name: String) -> String {
        String(name.prefix { $0 != "(" })
    }

    fileprivate static func hasAssociatedValues(_ enumCase: Declaration) -> Bool {
        enumCase.name.contains("(")
    }
}

/// The pattern sites collected while indexing, and the names written outside the index.
private struct PatternIndex {
    /// The names written in an `#if` clause or in a file left out by `index_exclude`.
    private(set) var namesOutsideTheIndex: Set<String>
    private let sites: [Location: EnumCasePatternSite]
    private let enumElementReferences: [Location: [Reference]]
    private let enumsReceivedByPatternOperators: Set<Declaration>
    private let graph: SourceGraph

    /// The indexed files are walked while indexing. The files left out by `index_exclude` are not indexed, so they
    /// are parsed here and their every name is collected.
    /// - Returns: `nil` when a file left out by `index_exclude` cannot be read.
    init?(
        indexExcludedFiles: Set<FilePath>,
        enumsReceivedByPatternOperators: Set<Declaration>,
        enumElementReferences: [Location: [Reference]],
        graph: SourceGraph
    ) {
        self.enumElementReferences = enumElementReferences
        self.enumsReceivedByPatternOperators = enumsReceivedByPatternOperators
        self.graph = graph
        sites = graph.enumCasePatternSites
        namesOutsideTheIndex = graph.enumCaseConditionalNames

        for path in indexExcludedFiles {
            guard let source = Self.read(path) else { return nil }

            for token in Parser.parse(source: source).tokens(viewMode: .sourceAccurate) {
                if case let .identifier(name) = token.tokenKind {
                    namesOutsideTheIndex.insert(name.trimmingCharacters(in: CharacterSet(charactersIn: "`")))
                }
            }
        }
    }

    private static func read(_ path: FilePath) -> String? {
        do {
            return try String(contentsOfFile: path.string, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Whether the reference at this location is certainly a pattern, and not a construction.
    func isPattern(_ location: Location, hasAssociatedValues: Bool) -> Bool {
        guard let site = sites[location] else { return false }

        // `.name(...)` is a case pattern only for a case with associated values.
        if site.shape == .call, !hasAssociatedValues {
            return false
        }

        return isInsideCasePattern(site)
    }

    /// The arguments of a call are sub-patterns only when the callee is itself a case pattern: a reference to a case
    /// with associated values, or to an external case (`Optional.some`, `Result.success`). When a `~=` operator
    /// receives the enum of the callee, the call is an expression pattern that builds its arguments.
    private func isInsideCasePattern(_ site: EnumCasePatternSite) -> Bool {
        guard let callLocation = site.enclosingCall else { return true }
        guard let calledCases = enumElementReferences[callLocation],
              let callSite = sites[callLocation],
              !calledCases.contains(where: isNotCasePatternCallee)
        else { return false }

        return isInsideCasePattern(callSite)
    }

    private func isNotCasePatternCallee(_ reference: Reference) -> Bool {
        guard let calledCase = graph.declaration(withUsr: reference.usr) else { return false }

        if let calledEnum = calledCase.parent, enumsReceivedByPatternOperators.contains(calledEnum) {
            return true
        }

        return !UnconstructedEnumCaseMarker.hasAssociatedValues(calledCase)
    }
}
