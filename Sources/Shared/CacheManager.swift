import Foundation

struct CacheEntryError: Error, CustomStringConvertible {
    let path: String
    let underlying: Error

    var description: String {
        "\(path): \(underlying.localizedDescription)"
    }
}

struct CacheClearError: Error, LocalizedError {
    let failures: [CacheEntryError]

    var errorDescription: String? {
        "Failed to clear the cache, the following entries could not be removed:\n"
            + failures.map { "  - \($0.description)" }.joined(separator: "\n")
    }
}

public struct EvictedCacheEntry: Equatable {
    public let name: String
    public let size: Int64
}

public enum CacheManager {
    public static let derivedDataPrefix = "DerivedData-"
    static let projectSidecarName = ".outskirts-project"

    /// Clears the outskirts cache directory and the one left by releases that predate the rename.
    public static func clearIncludingLegacy(cachesDirectory: URL? = nil, fileManager: FileManager = .default) throws {
        try clear(cacheDirectory: URL(fileURLWithPath: Constants.cachePath(cachesDirectory: cachesDirectory).string), fileManager: fileManager)
        try clear(cacheDirectory: URL(fileURLWithPath: Constants.legacyCachePath(cachesDirectory: cachesDirectory).string), fileManager: fileManager)
    }

    /// Removes every entry of the cache directory, then the directory itself. Entries that have already
    /// vanished are ignored. Symbolic links are removed, never followed.
    public static func clear(cacheDirectory: URL, fileManager: FileManager = .default) throws {
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
        } catch {
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                return
            }
            throw CacheClearError(failures: [CacheEntryError(path: cacheDirectory.path, underlying: error)])
        }

        var failures: [CacheEntryError] = []
        for entry in entries {
            do {
                try fileManager.removeItem(at: entry)
            } catch {
                if !isMissing(error) {
                    failures.append(CacheEntryError(path: entry.path, underlying: error))
                }
            }
        }

        if failures.isEmpty {
            do {
                try fileManager.removeItem(at: cacheDirectory)
            } catch {
                if !isMissing(error) {
                    failures.append(CacheEntryError(path: cacheDirectory.path, underlying: error))
                }
            }
        }

        if !failures.isEmpty {
            throw CacheClearError(failures: failures)
        }
    }

    /// Marks a DerivedData folder as used now.
    public static func touch(_ directory: URL, now: Date = Date(), fileManager: FileManager = .default) throws {
        try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: directory.path)
    }

    /// Records the project a DerivedData folder was built for, so that the folder can be evicted once the project is gone.
    /// Call it before `touch`: creating the file changes the folder's modification date.
    public static func recordProject(_ projectPath: String, in directory: URL, fileManager: FileManager = .default) throws {
        let sidecar = directory.appendingPathComponent(projectSidecarName)
        guard let data = projectPath.data(using: .utf8) else { return }

        if !fileManager.createFile(atPath: sidecar.path, contents: data) {
            throw CacheEntryError(path: sidecar.path, underlying: CocoaError(.fileWriteUnknown))
        }
    }

    /// Removes the `DerivedData-*` folders of the cache, except `keeping`, that are stale. A folder is stale when
    /// the project recorded in its sidecar no longer exists, or when its modification date is older than
    /// `maxAgeDays` (0 disables this age rule). Then, when `maxSizeBytes` is above 0, the least recently
    /// used folders are removed until the folders left fit in `maxSizeBytes` bytes (the size of `keeping` counts).
    @discardableResult
    public static func evictStale(
        cacheDirectory: URL,
        maxAgeDays: Int,
        maxSizeBytes: Int64 = 0,
        keeping: URL?,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> [EvictedCacheEntry] {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else { return [] }

        let cutoff = now.addingTimeInterval(-Double(maxAgeDays) * 86400)
        let keptName = keeping?.lastPathComponent
        let entries = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        )

        var evicted: [EvictedCacheEntry] = []
        var failures: [CacheEntryError] = []
        var remaining: [(url: URL, modified: Date, size: Int64)] = []
        var keptSize: Int64 = 0

        func remove(_ entry: URL, size: Int64) -> Bool {
            do {
                try fileManager.removeItem(at: entry)
                evicted.append(EvictedCacheEntry(name: entry.lastPathComponent, size: size))
                return true
            } catch {
                if isMissing(error) {
                    return true
                }
                failures.append(CacheEntryError(path: entry.path, underlying: error))
                return false
            }
        }

        for entry in entries where entry.lastPathComponent.hasPrefix(derivedDataPrefix) {
            let isKept = entry.lastPathComponent == keptName
            let modified = try entry.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let isStale = !isKept
                && (isOrphan(entry, fileManager: fileManager) || (maxAgeDays > 0 && (modified.map { $0 < cutoff } ?? false)))
            if !isStale, maxSizeBytes == 0 {
                continue
            }

            let size = directorySize(entry, fileManager: fileManager)
            if isStale {
                _ = remove(entry, size: size)
            } else if isKept {
                keptSize += size
            } else {
                remaining.append((entry, modified ?? .distantPast, size))
            }
        }

        if maxSizeBytes > 0 {
            let limit = maxSizeBytes
            var total = keptSize + remaining.reduce(0) { $0 + $1.size }
            for candidate in remaining.sorted(by: { $0.modified < $1.modified }) where total > limit {
                if remove(candidate.url, size: candidate.size) {
                    total -= candidate.size
                }
            }
        }

        if !failures.isEmpty {
            throw CacheClearError(failures: failures)
        }
        return evicted
    }

    // MARK: - Private

    /// Whether the folder records a project path that no longer exists. A folder without a sidecar is never an orphan.
    private static func isOrphan(_ directory: URL, fileManager: FileManager) -> Bool {
        let sidecar = directory.appendingPathComponent(projectSidecarName)
        guard let data = fileManager.contents(atPath: sidecar.path),
              let path = String(data: data, encoding: .utf8), !path.isEmpty else { return false }

        return !fileManager.fileExists(atPath: path)
    }

    private static func isMissing(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
    }

    private static func directorySize(_ url: URL, fileManager: FileManager) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
