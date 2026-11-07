import Foundation
import Shared
import SourceGraph
import SystemPackage

/// A baseline set of declarations that are excluded from results.
///
/// Version 1 holds the ids only. Version 2 gives each id the kind, the name and the file of the result it was written
/// for, so that a reviewer can read what a baseline holds. Matching only uses the ids, and both versions are read.
public enum Baseline: Codable, Equatable {
    case v1(usrs: [String])
    case v2(entries: [Entry])

    public struct Entry: Codable, Hashable {
        public let id: String
        /// What the id was written for. Absent for an entry carried over from a version 1 baseline.
        public let kind: String?
        public let name: String?
        /// The path of the file relative to the project root.
        public let file: String?

        public init(id: String, kind: String? = nil, name: String? = nil, file: String? = nil) {
            self.id = id
            self.kind = kind
            self.name = name
            self.file = file
        }

        init(id: String, result: ScanResult, projectRoot: FilePath) {
            let path = result.declaration.location.file.path.string
            let rootPrefix = projectRoot.string.hasSuffix("/") ? projectRoot.string : projectRoot.string + "/"

            self.init(
                id: id,
                kind: result.declaration.kind.rawValue,
                name: result.declaration.name,
                file: path.hasPrefix(rootPrefix) ? String(path.dropFirst(rootPrefix.count)) : path
            )
        }
    }

    public var entries: [Entry] {
        switch self {
        case let .v1(usrs):
            usrs.map { Entry(id: $0) }
        case let .v2(entries):
            entries
        }
    }

    public var usrs: Set<String> {
        switch self {
        case let .v1(usrs):
            Set(usrs)
        case let .v2(entries):
            Set(entries.map(\.id))
        }
    }

    /// The baseline that keeps only the entries of the results that a baseline matched.
    public static func pruned(keeping matchedResults: [ScanResult], projectRoot: FilePath) -> Baseline {
        .v2(entries: entries(of: matchedResults, projectRoot: projectRoot).values.sorted { $0.id < $1.id })
    }

    /// The baseline `--write-baseline` writes, in version 2: the results, and the entries of the baseline that was
    /// read, which are never dropped. A result replaces the entry of the same id.
    public static func written(from results: [ScanResult], union existing: Baseline?, projectRoot: FilePath) -> Baseline {
        var entries = Dictionary(uniqueKeysWithValues: (existing?.entries ?? []).map { ($0.id, $0) })
        entries.merge(Self.entries(of: results, projectRoot: projectRoot)) { _, new in new }
        return .v2(entries: entries.values.sorted { $0.id < $1.id })
    }

    private static func entries(of results: [ScanResult], projectRoot: FilePath) -> [String: Entry] {
        var entries: [String: Entry] = [:]

        for result in results {
            for usr in result.usrs where entries[usr] == nil {
                entries[usr] = Entry(id: usr, result: result, projectRoot: projectRoot)
            }
        }

        return entries
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

        let suffixes = legacyCatalogSuffixes(of: result)
        if !suffixes.isEmpty {
            let absoluteCatalogPrefix = SyntheticUsr.localizedStringPrefix + "/"

            for suffix in suffixes {
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
        legacyCatalogSuffixes(of: result).contains { legacyCatalogSuffixes.contains($0) }
    }

    /// The catalog-relative suffixes of a String Catalog key result, which legacy absolute-path entries end with.
    /// Empty when the baseline holds no legacy catalog entry.
    private func legacyCatalogSuffixes(of result: ScanResult) -> [String] {
        guard !legacyCatalogSuffixes.isEmpty, result.declaration.kind == .localizedString else { return [] }

        return result.usrs
            .filter { $0.hasPrefix(SyntheticUsr.localizedStringPrefix) }
            .map { "/" + $0.dropFirst(SyntheticUsr.localizedStringPrefix.count) }
    }
}
