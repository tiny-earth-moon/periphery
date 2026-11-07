import Configuration
import Foundation
import Shared
import SwiftParser
import SwiftSyntax
import SystemPackage

/// Marks enum cases that are only matched in patterns and never constructed: no value of such a case can exist, so
/// the case and the branches that match it are dead.
///
/// The index store does not tell a pattern from a construction, so the source files that reference a candidate case
/// are parsed, and every reference must sit at a name that `EnumCasePatternCollector` found at a pattern position.
/// Any other reference, in whatever expression, counts as a construction. A false positive would make users delete
/// live code, so every enum whose cases may be produced without a visible construction is skipped:
/// - raw representable, `CaseIterable`, `Codable`/`Decodable` and `CodingKey` enums, and `@objc` enums;
/// - enums conforming to a protocol that is not indexed (other than a few protocols without static requirements),
///   or to an indexed protocol with a static requirement named like the case;
/// - enums with a custom attribute (a macro may construct cases in code the index does not see);
/// - public enums whose public declarations are retained (`retain_public`, `retain_public_modules`);
/// - enums a custom `~=` operator may receive, as `~=` builds the value of an expression pattern;
/// - cases whose name is written in an `#if` clause, which may construct them in code that was not compiled.
final class UnconstructedEnumCaseMarker: SourceGraphMutator {
    /// External protocols that have no static requirement a case could satisfy.
    private static let safeExternalProtocols: Set<String> = [
        "BitwiseCopyable", "Comparable", "Copyable", "CustomDebugStringConvertible", "CustomStringConvertible",
        "Equatable", "Error", "Escapable", "Hashable", "Identifiable", "LocalizedError", "Sendable", "SendableMetatype",
    ]
    private static let dynamicCaseProtocols: Set<String> = ["CaseIterable", "RawRepresentable", "CodingKey"]
    private static let staticMemberKinds: Set<Declaration.Kind> = [.varStatic, .varClass, .functionMethodStatic, .functionMethodClass]

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

        let candidates = graph.declarations(ofKind: .enum)
            .filter { !enumsReceivedByPatternOperators.contains($0) && !isExcluded($0) }
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
        // A file that cannot be read may construct a case in an `#if` clause.
        guard let index = PatternIndex(
            referenceFiles: referencesByCase.values.flatMapSet { $0.mapSet(\.location.file) },
            allFiles: allSourceFiles(),
            enumElementReferences: Dictionary(grouping: graph.allReferences.filter { $0.declarationKind == .enumelement }, by: \.location),
            graph: graph
        ) else { return }

        for (enumCase, references) in referencesByCase {
            guard !index.conditionalNames.contains(Self.baseName(of: enumCase.name)) else { continue }

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

    private func allSourceFiles() -> Set<SourceFile> {
        graph.allDeclarations.mapSet(\.location.file)
            .union(graph.allReferences.mapSet(\.location.file))
            .filter { $0.path.extension == "swift" }
    }

    private static func baseName(of name: String) -> String {
        String(name.prefix { $0 != "(" })
    }

    fileprivate static func hasAssociatedValues(_ enumCase: Declaration) -> Bool {
        enumCase.name.contains("(")
    }
}

/// The pattern sites and `#if` names of the parsed source files.
private struct PatternIndex {
    private(set) var conditionalNames: Set<String> = []
    private var sites: [Location: EnumCasePatternCollector.Site] = [:]
    private let enumElementReferences: [Location: [Reference]]
    private let graph: SourceGraph

    /// - Parameter referenceFiles: the files referencing a candidate case, parsed for their pattern sites.
    /// - Parameter allFiles: every Swift file of the graph, parsed for their `#if` names when they hold an `#if`.
    /// - Returns: `nil` when a file cannot be read.
    init?(referenceFiles: Set<SourceFile>, allFiles: Set<SourceFile>, enumElementReferences: [Location: [Reference]], graph: SourceGraph) {
        self.enumElementReferences = enumElementReferences
        self.graph = graph

        for file in referenceFiles.union(allFiles) {
            let source: String
            do {
                source = try String(contentsOfFile: file.path.string, encoding: .utf8)
            } catch {
                return nil
            }

            guard referenceFiles.contains(file) || source.contains("#if") else { continue }

            let syntax = Parser.parse(source: source)
            let collector = EnumCasePatternCollector(
                file: file,
                locationConverter: SourceLocationConverter(fileName: file.path.string, tree: syntax)
            )
            collector.walk(syntax)
            conditionalNames.formUnion(collector.conditionalNames)
            sites.merge(collector.sites) { current, _ in current }
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
    /// with associated values, or to an external case (`Optional.some`, `Result.success`).
    private func isInsideCasePattern(_ site: EnumCasePatternCollector.Site) -> Bool {
        guard let callLocation = site.enclosingCall else { return true }
        guard let calledCases = enumElementReferences[callLocation],
              let callSite = sites[callLocation],
              !calledCases.contains(where: { reference in
                  graph.declaration(withUsr: reference.usr).map { !UnconstructedEnumCaseMarker.hasAssociatedValues($0) } ?? false
              })
        else { return false }

        return isInsideCasePattern(callSite)
    }
}
