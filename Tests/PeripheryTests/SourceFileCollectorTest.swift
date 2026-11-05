import Foundation
@testable import Indexer
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
}
