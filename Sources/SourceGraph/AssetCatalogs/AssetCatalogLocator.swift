import Foundation
import SystemPackage

/// Finds the asset directories of the asset catalogs (`*.xcassets`) under a project directory.
final class AssetCatalogLocator {
    private static let skippedDirectoryNames: Set<String> = ["DerivedData", "SourcePackages", "node_modules"]

    private let root: FilePath
    private lazy var catalogs: [FilePath] = findCatalogs()
    private var assetDirectories: [String: [FilePath]] = [:]

    init(root: FilePath) {
        self.root = root
    }

    /// The asset directories of the given asset, e.g. `Assets.xcassets/Brand/Primary.colorset` for a
    /// `Brand/Primary` color in a folder that provides a namespace. Empty when no catalog declares it.
    func assetPaths(named name: String, kind: AssetCatalogSymbolKind) -> [FilePath] {
        let components = name.split(separator: "/").map(String.init)
        guard let last = components.last else { return [] }

        let namespace = Array(components.dropLast())

        return directories(withExtension: kind.assetDirectoryExtension).filter { path in
            guard path.stem == last else { return false }

            let folders = path.removingLastComponent().components.map(\.string)
            return namespace.isEmpty || Array(folders.suffix(namespace.count)) == namespace
        }
    }

    // MARK: - Private

    private func directories(withExtension pathExtension: String) -> [FilePath] {
        if let directories = assetDirectories[pathExtension] {
            return directories
        }

        let directories = catalogs.flatMap { catalog in
            enumerateDirectories(in: catalog) { url in
                url.pathExtension == pathExtension ? .collect : .descend
            }
        }
        .sorted { $0.string < $1.string }
        assetDirectories[pathExtension] = directories
        return directories
    }

    private func findCatalogs() -> [FilePath] {
        enumerateDirectories(in: root) { url in
            if url.pathExtension == "xcassets" {
                return .collect
            }
            if Self.skippedDirectoryNames.contains(url.lastPathComponent) || url.pathExtension == "build" {
                return .skip
            }

            return .descend
        }
    }

    private enum Visit {
        case collect, descend, skip
    }

    /// Unreadable directories are not searched: an asset that only they hold is reported without its path.
    private func enumerateDirectories(in directory: FilePath, visit: (URL) -> Visit) -> [FilePath] {
        let url = URL(fileURLWithPath: directory.string, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [FilePath] = []

        for case let child as URL in enumerator {
            guard isDirectory(child) else { continue }

            switch visit(child) {
            case .collect:
                result.append(FilePath(child.path))
                enumerator.skipDescendants()
            case .skip:
                enumerator.skipDescendants()
            case .descend:
                break
            }
        }

        return result
    }

    private func isDirectory(_ url: URL) -> Bool {
        do {
            return try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        } catch {
            // An entry that cannot be read is not searched, like an unreadable directory.
            return false
        }
    }
}
