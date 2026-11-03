import Foundation
import SystemPackage

public enum Constants {
    static let cacheDirectoryName = "com.github.tiny-earth-moon.outskirts"
    static let legacyCacheDirectoryName = "com.github.tiny-earth-moon.periphery"

    private static let migrationLock = NSLock()
    private nonisolated(unsafe) static var migratedBaseDirectories = Set<String>()

    /// The outskirts cache directory. The first call per process moves a cache left by an earlier release
    /// (or deletes it when both exist). `cachesDirectory` defaults to the user caches directory.
    public static func cachePath(cachesDirectory: URL? = nil) throws -> FilePath {
        let base = try resolveCachesDirectory(cachesDirectory)
        try migrateLegacyCacheIfNeeded(in: base)
        return FilePath(base.appendingPathComponent(cacheDirectoryName).path)
    }

    /// The cache directory used by releases that predate the rename.
    public static func legacyCachePath(cachesDirectory: URL? = nil) throws -> FilePath {
        let base = try resolveCachesDirectory(cachesDirectory)
        return FilePath(base.appendingPathComponent(legacyCacheDirectoryName).path)
    }

    private static func resolveCachesDirectory(_ override: URL?) throws -> URL {
        if let override {
            return override
        }
        return try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    private static func migrateLegacyCacheIfNeeded(in base: URL) throws {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        guard !migratedBaseDirectories.contains(base.path) else { return }

        let fileManager = FileManager.default
        let legacy = base.appendingPathComponent(legacyCacheDirectoryName)
        let current = base.appendingPathComponent(cacheDirectoryName)

        if fileManager.fileExists(atPath: legacy.path) {
            if fileManager.fileExists(atPath: current.path) {
                try fileManager.removeItem(at: legacy)
            } else {
                try fileManager.moveItem(at: legacy, to: current)
            }
        }

        migratedBaseDirectories.insert(base.path)
    }
}
