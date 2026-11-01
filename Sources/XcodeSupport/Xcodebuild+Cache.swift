import Foundation
import Shared

public extension Xcodebuild {
    /// Marks the DerivedData folder of the current scan as used, then evicts the stale ones from the cache.
    /// Returns the evicted entries.
    func refreshCache(project: XcodeProjectlike, schemes: [String], maxAgeDays: Int) throws -> [EvictedCacheEntry] {
        let current = try derivedDataPath(for: project, schemes: schemes)
        let currentURL = URL(fileURLWithPath: current.string)
        if FileManager.default.fileExists(atPath: currentURL.path) {
            try CacheManager.touch(currentURL)
        }
        return try CacheManager.evictStale(
            cacheDirectory: URL(fileURLWithPath: Constants.cachePath().string),
            maxAgeDays: maxAgeDays,
            keeping: currentURL
        )
    }
}
