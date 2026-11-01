import Foundation

public struct CacheEntryError: Error, CustomStringConvertible {
    public let path: String
    public let underlying: Error

    public var description: String {
        "\(path): \(underlying.localizedDescription)"
    }
}

public struct CacheClearError: Error, LocalizedError {
    public let failures: [CacheEntryError]

    public var errorDescription: String? {
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

    /// Removes the `DerivedData-*` folders of the cache whose modification date is older than `maxAgeDays`,
    /// except `keeping`. `maxAgeDays` of 0 disables eviction.
    @discardableResult
    public static func evictStale(
        cacheDirectory: URL,
        maxAgeDays: Int,
        keeping: URL?,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> [EvictedCacheEntry] {
        guard maxAgeDays > 0, fileManager.fileExists(atPath: cacheDirectory.path) else { return [] }

        let cutoff = now.addingTimeInterval(-Double(maxAgeDays) * 86400)
        let keptName = keeping?.lastPathComponent
        let entries = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        )

        var evicted: [EvictedCacheEntry] = []
        var failures: [CacheEntryError] = []
        for entry in entries where entry.lastPathComponent.hasPrefix(derivedDataPrefix) && entry.lastPathComponent != keptName {
            guard let modified = try entry.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modified < cutoff else { continue }

            let size = directorySize(entry, fileManager: fileManager)
            do {
                try fileManager.removeItem(at: entry)
                evicted.append(EvictedCacheEntry(name: entry.lastPathComponent, size: size))
            } catch {
                if !isMissing(error) {
                    failures.append(CacheEntryError(path: entry.path, underlying: error))
                }
            }
        }

        if !failures.isEmpty {
            throw CacheClearError(failures: failures)
        }
        return evicted
    }

    // MARK: - Private

    private static func isMissing(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
    }

    private static func directorySize(_ url: URL, fileManager: FileManager) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
