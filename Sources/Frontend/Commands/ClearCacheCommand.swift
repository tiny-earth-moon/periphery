import ArgumentParser
import Foundation
import Shared

struct ClearCacheCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear-cache",
        abstract: "Clear Periphery's build cache"
    )

    func run() throws {
        try CacheManager.clear(cacheDirectory: URL(fileURLWithPath: Constants.cachePath().string))
    }
}
