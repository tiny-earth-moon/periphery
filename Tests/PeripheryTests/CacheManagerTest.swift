import Foundation
@testable import Shared
import XCTest

final class CacheManagerTest: XCTestCase {
    private var root: URL!
    private var cache: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("periphery-cache-test-\(UUID().uuidString)")
        cache = root.appendingPathComponent("cache")
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Restore permissions so the fake root can always be removed.
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        }
        try fm.removeItem(at: root)
    }

    private func makeDerivedData(_ name: String, ageDays: Int) throws -> URL {
        let dir = cache.appendingPathComponent(name)
        let nested = dir.appendingPathComponent("Index/DataStore")
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4096).write(to: nested.appendingPathComponent("record"))
        let date = Date().addingTimeInterval(-Double(ageDays) * 86400)
        try fm.setAttributes([.modificationDate: date], ofItemAtPath: dir.path)
        return dir
    }

    func testClearCache_removesNestedEntriesAndDirectory() throws {
        _ = try makeDerivedData("DerivedData-a", ageDays: 1)
        _ = try makeDerivedData("DerivedData-b", ageDays: 1)
        let outside = root.appendingPathComponent("outside")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data([1]).write(to: outside.appendingPathComponent("keep"))
        try fm.createSymbolicLink(at: cache.appendingPathComponent("link"), withDestinationURL: outside)

        try CacheManager.clear(cacheDirectory: cache)

        XCTAssertFalse(fm.fileExists(atPath: cache.path))
        XCTAssertTrue(fm.fileExists(atPath: outside.appendingPathComponent("keep").path))
    }

    func testClearCache_missingDirectoryIsNotAnError() throws {
        try fm.removeItem(at: cache)
        XCTAssertNoThrow(try CacheManager.clear(cacheDirectory: cache))
    }

    func testClearCache_listsEntryThatCannotBeRemoved() throws {
        let locked = try makeDerivedData("DerivedData-locked", ageDays: 1)
        let removable = try makeDerivedData("DerivedData-ok", ageDays: 1)
        // A directory without write permission prevents removing its children.
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.appendingPathComponent("Index").path)

        XCTAssertThrowsError(try CacheManager.clear(cacheDirectory: cache)) { error in
            guard let clearError = error as? CacheClearError else { return XCTFail("unexpected error \(error)") }

            XCTAssertEqual(clearError.failures.map { URL(fileURLWithPath: $0.path).lastPathComponent }, ["DerivedData-locked"])
            XCTAssertTrue(clearError.localizedDescription.contains("DerivedData-locked"))
        }
        XCTAssertFalse(fm.fileExists(atPath: removable.path))
        XCTAssertTrue(fm.fileExists(atPath: locked.path))
    }

    func testEvict_removesStaleKeepsRecentAndCurrent() throws {
        let stale = try makeDerivedData("DerivedData-stale", ageDays: 30)
        let recent = try makeDerivedData("DerivedData-recent", ageDays: 2)
        let current = try makeDerivedData("DerivedData-current", ageDays: 60)
        let unrelated = cache.appendingPathComponent("other")
        try fm.createDirectory(at: unrelated, withIntermediateDirectories: true)
        try fm.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: unrelated.path)

        let evicted = try CacheManager.evictStale(cacheDirectory: cache, maxAgeDays: 14, keeping: current)

        XCTAssertEqual(evicted.map(\.name), ["DerivedData-stale"])
        XCTAssertGreaterThan(evicted[0].size, 0)
        XCTAssertFalse(fm.fileExists(atPath: stale.path))
        XCTAssertTrue(fm.fileExists(atPath: recent.path))
        XCTAssertTrue(fm.fileExists(atPath: current.path))
        XCTAssertTrue(fm.fileExists(atPath: unrelated.path))
    }

    func testEvict_zeroDisablesEviction() throws {
        let stale = try makeDerivedData("DerivedData-stale", ageDays: 365)

        let evicted = try CacheManager.evictStale(cacheDirectory: cache, maxAgeDays: 0, keeping: nil)

        XCTAssertTrue(evicted.isEmpty)
        XCTAssertTrue(fm.fileExists(atPath: stale.path))
    }
}
