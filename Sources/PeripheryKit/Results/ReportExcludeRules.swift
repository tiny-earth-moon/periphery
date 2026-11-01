import Configuration
import FilenameMatcher
import Foundation
import Shared
import SourceGraph

/// Result kind identifiers accepted by `report_exclude`.
///
/// A result kind is its annotation name (as emitted in the `hints` of a report), optionally followed by the
/// declaration kind (as emitted in the `kind` of a JSON report), e.g. `unused`, `unused.function.free`,
/// `assignOnlyProperty.var.instance`. An identifier matches a result if it is equal to, or a dotted prefix of,
/// the result identifier, so `unused.function` matches every unused function and method.
public enum ResultKind {
    static let annotationNames: Set<String> = Set([
        "unused", "assignOnlyProperty", "unassignedOptionalProperty", "redundantProtocol", "redundantPublicAccessibility",
        "redundantOpenAccessibility", "missingFinal", "redundantAccessLevel", "superfluousIgnoreCommand",
    ]).union(AssetCatalogSymbolKind.allCases.map(\.annotationName))

    static let identifiers: Set<String> = annotationNames.union(annotationNames.flatMap { annotation in
        Declaration.Kind.identifiers.map { "\(annotation).\($0)" }
    })

    public static func isValid(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }

    static func identifier(of result: ScanResult) -> String {
        let annotation = describeAnnotation(result.annotation)
        return "\(annotation).\(result.declaration.kind.rawValue)"
    }

    static func matches(_ identifier: String, resultIdentifier: String) -> Bool {
        resultIdentifier == identifier || resultIdentifier.hasPrefix("\(identifier).")
    }

    private static func describeAnnotation(_ annotation: ScanResult.Annotation) -> String {
        switch annotation {
        case .unused: "unused"
        case .assignOnlyProperty: "assignOnlyProperty"
        case .unassignedOptionalProperty: "unassignedOptionalProperty"
        case .redundantProtocol: "redundantProtocol"
        case .redundantPublicAccessibility: "redundantPublicAccessibility"
        case .redundantOpenAccessibility: "redundantOpenAccessibility"
        case .missingFinal: "missingFinal"
        case .redundantAccessLevel: "redundantAccessLevel"
        case .superfluousIgnoreCommand: "superfluousIgnoreCommand"
        case let .unusedAssetCatalogSymbol(symbol): symbol.kind.annotationName
        }
    }
}

public struct ReportExcludeRule {
    let matcher: FilenameMatcher
    /// `nil` excludes every result.
    let kinds: [String]?

    func excludes(_ result: ScanResult, path: String) -> Bool {
        guard matcher.match(filename: path) else { return false }
        guard let kinds else { return true }

        let identifier = ResultKind.identifier(of: result)
        return kinds.contains { ResultKind.matches($0, resultIdentifier: identifier) }
    }

    /// Resolves the configured entries, throwing a configuration error for any malformed entry or unknown kind.
    public static func resolve(_ configuration: Configuration) throws -> [ReportExcludeRule] {
        try configuration.reportExclude.map { entry in
            switch entry {
            case let .pattern(string):
                let (path, kinds) = try splitCompact(string)
                return ReportExcludeRule(matcher: matcher(path, configuration), kinds: kinds)
            case let .scoped(path, kinds):
                guard !kinds.isEmpty else {
                    throw PeripheryError.usageError("report_exclude: 'kinds' is empty for '\(path)', omit it to exclude every result.")
                }

                try validate(kinds, in: path)
                return ReportExcludeRule(matcher: matcher(path, configuration), kinds: kinds)
            case let .malformed(description):
                throw PeripheryError.usageError("report_exclude: invalid entry \(description). Expected a glob, '<glob>:kind1,kind2', or {path: <glob>, kinds: [<kind>]}.")
            }
        }
    }

    private static func matcher(_ path: String, _ configuration: Configuration) -> FilenameMatcher {
        configuration.buildFilenameMatchers(with: [path])[0]
    }

    private static func validate(_ kinds: [String], in path: String) throws {
        for kind in kinds where !ResultKind.isValid(kind) {
            throw PeripheryError.usageError("report_exclude: unknown result kind '\(kind)' for '\(path)'. Valid kinds start with one of: \(ResultKind.annotationNames.sorted().joined(separator: ", ")), e.g. 'unused.function'.")
        }
    }

    /// Splits `<glob>:kind1,kind2` only when the part after the last `:` is a list of kinds, so globs are never broken.
    private static func splitCompact(_ string: String) throws -> (String, [String]?) {
        guard let separator = string.lastIndex(of: ":") else { return (string, nil) }

        let path = String(string[..<separator])
        let kinds = string[string.index(after: separator)...]
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard !path.isEmpty, !kinds.isEmpty, !kinds.contains(where: \.isEmpty) else { return (string, nil) }

        if kinds.allSatisfy(ResultKind.isValid) {
            return (path, kinds)
        }

        // A tail that starts like a kind but is unknown is a typo, not part of a glob.
        let looksLikeKinds = kinds.allSatisfy { kind in
            ResultKind.annotationNames.contains { kind == $0 || kind.hasPrefix("\($0).") }
        }

        if looksLikeKinds {
            try validate(kinds, in: path)
        }

        return (string, nil)
    }
}
