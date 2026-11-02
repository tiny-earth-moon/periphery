import Configuration
import SystemPackage
@testable import TestShared
import XCTest

/// Scoped imports (`import struct Module.Type`) must not count as a use of their own module.
final class UnusedScopedImportTest: SPMSourceGraphTestCase {
    private static let fixtureDirectory = FixturesProjectPath.appending("Sources/UnusedImportScopedFixtures")
    private static let module = "UnusedImportScopedSupportFixtures"

    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)

        let files = try! FileManager.default
            .contentsOfDirectory(atPath: fixtureDirectory.appending("Client").string)
            .map { fixtureDirectory.appending("Client").appending($0) }
        index(sourceFiles: files + [fixtureDirectory.appending("Support/ScopedSupport.swift")], configuration: Configuration())
    }

    func testUnusedScopedImportsAreReported() {
        for kind in ["Struct", "Class", "Enum", "Protocol", "Function", "Variable"] {
            XCTAssertEqual(
                unusedImportedModules(inFileNamed: "Scoped\(kind)Unused.swift"),
                [Self.module],
                "import of a \(kind)"
            )
        }
    }

    func testUsedScopedImportsAreNotReported() {
        for kind in ["Struct", "Enum", "Function"] {
            XCTAssertEqual(unusedImportedModules(inFileNamed: "Scoped\(kind)Used.swift"), [], "import of a \(kind)")
        }
    }

    func testUnusedPlainImportIsStillReported() {
        XCTAssertEqual(unusedImportedModules(inFileNamed: "PlainImportUnused.swift"), [Self.module])
    }
}
