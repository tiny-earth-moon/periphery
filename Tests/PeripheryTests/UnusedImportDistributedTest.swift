import Configuration
import SystemPackage
@testable import TestShared
import XCTest

/// The `distributed` modifier requires `import Distributed` but leaves no reference in the index store.
final class UnusedImportDistributedTest: SPMSourceGraphTestCase {
    private static let fixtureDirectory = FixturesProjectPath.appending("Sources/UnusedImportDistributedFixtures")

    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)

        let configuration = Configuration()
        configuration.enableUnusedSystemImports = true
        index(
            sourceFiles: [
                "DistributedGreeter.swift",
                "DistributedGreeterExtension.swift",
                "DistributedImportWithoutModifier.swift",
            ].map { fixtureDirectory.appending($0) },
            configuration: configuration
        )
    }

    func testImportIsNotReportedInFileDeclaringDistributedMembers() {
        XCTAssertEqual(unusedImportedModules(inFileNamed: "DistributedGreeterExtension.swift"), [])
    }

    func testImportIsNotReportedInFileDeclaringDistributedActor() {
        XCTAssertEqual(unusedImportedModules(inFileNamed: "DistributedGreeter.swift"), [])
    }

    func testImportIsReportedInFileWithoutDistributedModifier() {
        XCTAssertEqual(unusedImportedModules(inFileNamed: "DistributedImportWithoutModifier.swift"), ["Distributed"])
    }
}
