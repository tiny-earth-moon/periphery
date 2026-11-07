import Configuration
import Logger
@testable import SourceGraph
import XCTest

/// The known Apple SDK re-exports apply to stores built for Apple platforms only.
final class SystemModuleExportsTest: XCTestCase {
    func testLinuxFoundationDoesNotExportTheAppleOnlyModules() {
        let graph = makeGraph(targets: ["x86_64-unknown-linux-gnu"])

        XCTAssertFalse(graph.moduleExportsUnindexedModules("Foundation"))
        XCTAssertTrue(graph.isModule("Dispatch", exportedBy: "Foundation"))
        XCTAssertFalse(graph.isModule("Darwin", exportedBy: "Foundation"))
    }

    func testAppleFoundationKeepsTheKnownReexports() {
        let graph = makeGraph(targets: ["arm64-apple-macosx15.0"])

        XCTAssertTrue(graph.moduleExportsUnindexedModules("Foundation"))
        XCTAssertTrue(graph.isModule("Darwin", exportedBy: "Foundation"))
        XCTAssertTrue(graph.isModule("ObjectiveC", exportedBy: "Foundation"))
    }

    func testUnknownTargetKeepsTheKnownReexports() {
        let graph = makeGraph(targets: [""])

        XCTAssertTrue(graph.isModule("Darwin", exportedBy: "Foundation"))
    }

    // MARK: - Private

    /// A store holding Foundation, Dispatch and FoundationEssentials, as on Linux.
    private func makeGraph(targets: Set<String>) -> SourceGraph {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let graph = SourceGraph(configuration: Configuration(), logger: logger)
        graph.addSystemModules(
            ["Foundation", "FoundationEssentials", "Dispatch"],
            exports: ["Foundation": ["FoundationEssentials", "Dispatch"]],
            modulesByUsr: [:],
            targets: targets
        )
        graph.indexingComplete()
        return graph
    }
}
