import Foundation
import Shared

public extension Xcodebuild {
    /// Refreshes the build cache around the DerivedData folder of the current scan. Returns the evicted entries.
    func refreshCache(project: XcodeProjectlike, schemes: [String], buildArguments: [String] = [], maxAgeDays: Int, maxSizeGB: Int = 0) throws -> [EvictedCacheEntry] {
        let current = try derivedDataPath(for: project, schemes: schemes, buildArguments: buildArguments)
        return try CacheManager.refresh(
            derivedData: URL(fileURLWithPath: current.string),
            projectPath: project.path.lexicallyNormalized().string,
            maxAgeDays: maxAgeDays,
            maxSizeGB: maxSizeGB
        )
    }
}
