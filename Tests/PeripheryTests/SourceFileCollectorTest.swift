import Foundation
@testable import Indexer
import Shared
import SystemPackage
import XCTest

final class SourceFileCollectorTest: XCTestCase {
    private struct Unit: Equatable {
        let name: String
        let module: String
        let date: Date?
    }

    private let edited = Date(timeIntervalSince1970: 1000)

    private func current(_ units: [Unit], sourceModificationDate: Date?) -> [String] {
        SourceFileCollector.currentUnits(
            units,
            sourceModificationDate: sourceModificationDate,
            module: \.module,
            modificationDate: \.date
        ).map(\.name)
    }

    /// A renamed package (or a restored CI cache) leaves the previous build's units next to the new ones.
    func testUnitOlderThanSource_isDroppedWhenItsModuleHasACurrentUnit() {
        let units = [
            Unit(name: "stale", module: "Frontend", date: edited.addingTimeInterval(-60)),
            Unit(name: "fresh", module: "Frontend", date: edited.addingTimeInterval(60)),
        ]

        XCTAssertEqual(current(units, sourceModificationDate: edited), ["fresh"])
    }

    func testUnitsOfSeveralProducts_areAllKeptWhenCurrent() {
        let units = [
            Unit(name: "outskirts", module: "Frontend", date: edited.addingTimeInterval(10)),
            Unit(name: "periphery", module: "Frontend", date: edited.addingTimeInterval(20)),
            Unit(name: "testable", module: "Frontend", date: edited),
        ]

        XCTAssertEqual(current(units, sourceModificationDate: edited), ["outskirts", "periphery", "testable"])
    }

    func testOnlyUnitsOlderThanSource_areKept() {
        let units = [
            Unit(name: "a", module: "Frontend", date: edited.addingTimeInterval(-60)),
            Unit(name: "b", module: "Frontend", date: edited.addingTimeInterval(-30)),
        ]

        XCTAssertEqual(current(units, sourceModificationDate: edited), ["a", "b"])
    }

    func testOutdatedUnitOfAnotherModule_isKept() {
        let units = [
            Unit(name: "lib", module: "Lib", date: edited.addingTimeInterval(60)),
            Unit(name: "app", module: "App", date: edited.addingTimeInterval(-60)),
        ]

        XCTAssertEqual(current(units, sourceModificationDate: edited), ["lib", "app"])
    }

    func testUnknownDates_keepAllUnits() {
        let units = [
            Unit(name: "undated", module: "Frontend", date: nil),
            Unit(name: "fresh", module: "Frontend", date: edited.addingTimeInterval(60)),
            Unit(name: "stale", module: "Frontend", date: edited.addingTimeInterval(-60)),
        ]

        XCTAssertEqual(current(units, sourceModificationDate: edited), ["undated", "fresh"])
        XCTAssertEqual(current(units, sourceModificationDate: nil), ["undated", "fresh", "stale"])
    }

    private func outdated(_ units: [Unit], sourceModificationDate: Date?) -> [String] {
        let kept = SourceFileCollector.currentUnits(
            units,
            sourceModificationDate: sourceModificationDate,
            module: \.module,
            modificationDate: \.date
        )

        return SourceFileCollector.outdatedUnits(
            kept,
            sourceModificationDate: sourceModificationDate,
            modificationDate: \.date
        ).map(\.name)
    }

    /// Edited after the last build, scanned with `--skip-build`: the only units of the file describe an older version.
    func testSourceNewerThanItsOnlyUnits_isOutdated() {
        let units = [
            Unit(name: "macos", module: "Kit", date: edited.addingTimeInterval(-60)),
            Unit(name: "ios", module: "Kit", date: edited.addingTimeInterval(-30)),
        ]

        XCTAssertEqual(outdated(units, sourceModificationDate: edited), ["macos", "ios"])
    }

    func testUnitsWrittenAfterTheSource_areNotOutdated() {
        let units = [
            Unit(name: "macos", module: "Kit", date: edited.addingTimeInterval(60)),
            Unit(name: "ios", module: "Kit", date: edited),
        ]

        XCTAssertEqual(outdated(units, sourceModificationDate: edited), [])
    }

    /// The stale unit is dropped in favour of the fresh one, so the results are correct and need no warning.
    func testStaleUnitBesideAFreshUnitOfItsModule_isNotOutdated() {
        let units = [
            Unit(name: "ios", module: "Kit", date: edited.addingTimeInterval(-60)),
            Unit(name: "macos", module: "Kit", date: edited.addingTimeInterval(60)),
        ]

        XCTAssertEqual(outdated(units, sourceModificationDate: edited), [])
    }

    func testUnknownDates_areNotOutdated() {
        let units = [
            Unit(name: "undated", module: "Kit", date: nil),
            Unit(name: "stale", module: "Kit", date: edited.addingTimeInterval(-60)),
        ]

        XCTAssertEqual(outdated(units, sourceModificationDate: edited), ["stale"])
        XCTAssertEqual(outdated(units, sourceModificationDate: nil), [])
        XCTAssertEqual(outdated([units[0]], sourceModificationDate: edited), [])
    }

    func testOutdatedIndexWarning_isNilWithoutOutdatedFiles() {
        XCTAssertNil(SourceFileCollector.outdatedIndexWarning([:], relativeTo: "/project"))
        XCTAssertNil(SourceFileCollector.outdatedIndexWarning(["/project/.build/out": []], relativeTo: "/project"))
    }

    func testOutdatedIndexWarning_namesTheStoreAndTheFile() {
        let warning = SourceFileCollector.outdatedIndexWarning(
            ["/project/.build-ios/out": ["/project/Sources/Kit/SameName.swift"]],
            relativeTo: "/project"
        )

        XCTAssertEqual(
            warning,
            "1 source file is newer than its index data in .build-ios/out: Sources/Kit/SameName.swift. Results in it may be at the wrong lines or missing: rebuild the project before scanning, or pass '--clean-build' to start from an empty index store."
        )
    }

    func testOutdatedIndexWarning_countsEveryFileAndListsAFewPerStore() {
        let mac: Set<FilePath> = ["/project/Sources/A.swift", "/project/Sources/B.swift"]
        let ios: Set<FilePath> = Set((1 ... 5).map { FilePath("/project/Sources/F\($0).swift") })
        let warning = SourceFileCollector.outdatedIndexWarning(
            ["/project/.build-mac/out": mac, "/elsewhere/DataStore": ios],
            relativeTo: "/project"
        )

        XCTAssertEqual(
            warning,
            "7 source files are newer than their index data: 5 in /elsewhere/DataStore (Sources/F1.swift, Sources/F2.swift, Sources/F3.swift and 2 more), 2 in .build-mac/out (Sources/A.swift, Sources/B.swift). Results in them may be at the wrong lines or missing: rebuild the project before scanning, or pass '--clean-build' to start from an empty index store."
        )
    }

    func testStrictIndex_failsTheScanOnOutdatedFiles() {
        let outdated: [FilePath: Set<FilePath>] = ["/project/.build/out": ["/project/Sources/Beta.swift"]]

        XCTAssertThrowsError(try SourceFileCollector.outdatedIndexWarning(outdated, relativeTo: "/project", strict: true)) { error in
            guard case let .outdatedIndexData(message)? = error as? PeripheryError else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertTrue(message.hasPrefix("1 source file is newer than its index data in .build/out: Sources/Beta.swift."))
            XCTAssertTrue(message.hasSuffix("Failing as '--strict-index' is set."))
        }
    }

    func testStrictIndex_passesWithAFreshIndex() throws {
        XCTAssertNil(try SourceFileCollector.outdatedIndexWarning([:], relativeTo: "/project", strict: true))
        XCTAssertNil(try SourceFileCollector.outdatedIndexWarning(["/project/.build/out": []], relativeTo: "/project", strict: true))
    }

    func testWithoutStrictIndex_outdatedFilesOnlyWarn() throws {
        let outdated: [FilePath: Set<FilePath>] = ["/project/.build/out": ["/project/Sources/Beta.swift"]]

        XCTAssertEqual(
            try SourceFileCollector.outdatedIndexWarning(outdated, relativeTo: "/project", strict: false),
            SourceFileCollector.outdatedIndexWarning(outdated, relativeTo: "/project")
        )
    }
}
