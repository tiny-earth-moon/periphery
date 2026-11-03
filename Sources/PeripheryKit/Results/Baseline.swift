import Foundation
import Shared
import SourceGraph
import SystemPackage

/// A baseline set of declarations that are excluded from results.
public enum Baseline: Codable {
    case v1(usrs: [String])

    public var usrs: Set<String> {
        switch self {
        case let .v1(usrs):
            Set(usrs)
        }
    }

    /// The baseline that keeps only the entries of the results that a baseline matched.
    public static func pruned(keeping matchedResults: [ScanResult]) -> Baseline {
        .v1(usrs: matchedResults.flatMapSet(\.usrs).sorted())
    }

    /// The baseline `--write-baseline` writes: the results, and the entries of the baseline that was read, which are
    /// never dropped.
    public static func written(from results: [ScanResult], union existing: Baseline?) -> Baseline {
        .v1(usrs: results.flatMapSet(\.usrs).union(existing?.usrs ?? []).sorted())
    }

    /// The file contents: pretty-printed with sorted keys, slashes left unescaped and a trailing newline, so that
    /// a diff shows what changed and the same baseline always gives the same bytes.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self) + Data("\n".utf8)
    }

    /// Writes the file atomically: the contents go to a temporary file that replaces the destination, so that an
    /// interrupted run never leaves a truncated baseline.
    public func write(to path: FilePath) throws {
        try encoded().write(to: path.url, options: .atomic)
    }

    /// Reads a baseline file, reporting the key at fault when the file is not a baseline.
    public static func load(from path: FilePath) throws -> Baseline {
        let data = try Data(contentsOf: path.url)

        do {
            return try JSONDecoder().decode(Baseline.self, from: data)
        } catch let error as DecodingError {
            throw PeripheryError.usageError("Invalid baseline \(path.string): \(error.readableReason())")
        }
    }
}

/// Decides which results a baseline excludes.
///
/// Besides the ids of the current version, it recognises the ones earlier versions wrote, so that an existing
/// baseline keeps working: the position based ids of unused imports and empty extensions, and the absolute path of
/// a String Catalog, which also matches the same catalog in another checkout of the project.
struct BaselineMatcher {
    enum Match {
        case current
        case legacy
    }

    private let usrs: Set<String>
    private let projectRoot: FilePath
    private let legacyCatalogSuffixes: Set<String>

    init(_ baseline: Baseline, projectRoot: FilePath) {
        usrs = baseline.usrs
        self.projectRoot = projectRoot

        // The checkout that wrote an old entry is unknown, so each of its trailing paths is a candidate for the
        // path of the catalog relative to the project root.
        let absoluteCatalogPrefix = SyntheticUsr.localizedStringPrefix + "/"
        legacyCatalogSuffixes = usrs
            .filter { $0.hasPrefix(absoluteCatalogPrefix) }
            .reduce(into: []) { suffixes, entry in
                let path = entry.dropFirst(SyntheticUsr.localizedStringPrefix.count)

                for index in path.indices where path[index] == "/" {
                    suffixes.insert(String(path[index...]))
                }
            }
    }

    func match(_ result: ScanResult) -> Match? {
        if !result.usrs.isDisjoint(with: usrs) {
            return .current
        }

        if !result.legacyUsrs(projectRoot: projectRoot).isDisjoint(with: usrs) {
            return .legacy
        }

        if matchesLegacyCatalogEntry(result) {
            return .legacy
        }

        return nil
    }

    /// The entries of the baseline that a matched result accounts for.
    func entries(matchedBy result: ScanResult) -> Set<String> {
        var matched = result.usrs.union(result.legacyUsrs(projectRoot: projectRoot)).intersection(usrs)

        if !legacyCatalogSuffixes.isEmpty, result.declaration.kind == .localizedString {
            let absoluteCatalogPrefix = SyntheticUsr.localizedStringPrefix + "/"

            for usr in result.usrs where usr.hasPrefix(SyntheticUsr.localizedStringPrefix) {
                let suffix = "/" + usr.dropFirst(SyntheticUsr.localizedStringPrefix.count)

                for entry in usrs where entry.hasPrefix(absoluteCatalogPrefix) && entry.hasSuffix(suffix) {
                    matched.insert(entry)
                }
            }
        }

        return matched
    }

    /// The entries of the baseline that no result matches.
    func staleEntries(given matchedEntries: Set<String>) -> [String] {
        usrs.subtracting(matchedEntries).sorted()
    }

    // MARK: - Private

    private func matchesLegacyCatalogEntry(_ result: ScanResult) -> Bool {
        guard !legacyCatalogSuffixes.isEmpty, result.declaration.kind == .localizedString else { return false }

        return result.usrs.contains { usr in
            guard usr.hasPrefix(SyntheticUsr.localizedStringPrefix) else { return false }

            return legacyCatalogSuffixes.contains("/" + usr.dropFirst(SyntheticUsr.localizedStringPrefix.count))
        }
    }
}
