import Foundation
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

    // MARK: - Private

    private func matchesLegacyCatalogEntry(_ result: ScanResult) -> Bool {
        guard !legacyCatalogSuffixes.isEmpty, result.declaration.kind == .localizedString else { return false }

        return result.usrs.contains { usr in
            guard usr.hasPrefix(SyntheticUsr.localizedStringPrefix) else { return false }

            return legacyCatalogSuffixes.contains("/" + usr.dropFirst(SyntheticUsr.localizedStringPrefix.count))
        }
    }
}
