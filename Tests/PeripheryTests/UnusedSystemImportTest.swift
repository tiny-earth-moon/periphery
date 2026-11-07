import Configuration
@testable import SourceGraph
import SystemPackage
@testable import TestShared
import XCTest

/// Tests for unused imports of system frameworks (`enable_unused_system_imports`).
final class UnusedSystemImportTest: SPMSourceGraphTestCase {
    private static let fixtureDirectory = FixturesProjectPath.appending("Sources/UnusedSystemImportFixtures")
    private static let fixtureFiles = [
        "UnusedFoundationImport.swift",
        "ReexportedDispatchImport.swift",
        "DirectFoundationImport.swift",
        "ObjCFoundationImport.swift",
    ]

    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)
    }

    func testSystemImportsAreNotReportedWithoutTheOption() {
        indexFixtures(enableUnusedSystemImports: false)

        for fileName in Self.fixtureFiles {
            XCTAssertEqual(unusedImportedModules(inFileNamed: fileName), [], fileName)
        }
    }

    func testUnusedSystemImportIsReported() {
        indexFixtures(enableUnusedSystemImports: true)

        XCTAssertEqual(unusedImportedModules(inFileNamed: "UnusedFoundationImport.swift"), ["Foundation"])
    }

    func testSystemImportUsedThroughReexportedModuleIsNotReported() {
        indexFixtures(enableUnusedSystemImports: true)

        XCTAssertEqual(unusedImportedModules(inFileNamed: "ReexportedDispatchImport.swift"), [])
    }

    func testDirectlyUsedSystemImportsAreNotReported() {
        indexFixtures(enableUnusedSystemImports: true)

        XCTAssertEqual(unusedImportedModules(inFileNamed: "DirectFoundationImport.swift"), [])
        XCTAssertEqual(unusedImportedModules(inFileNamed: "ObjCFoundationImport.swift"), [])
    }

    func testSwiftUsrModules() {
        XCTAssertEqual(SystemModuleUsr.modules(in: "s:10Foundation3URLV"), ["Foundation"])
        XCTAssertEqual(SystemModuleUsr.modules(in: "s:SS10FoundationE4data5using20allowLossyConversionAA4DataVSgSSAAE8EncodingV_SbtF"), ["Swift", "Foundation"])
        XCTAssertEqual(SystemModuleUsr.modules(in: "s:7SwiftUI4TextV"), ["SwiftUI"])
        XCTAssertEqual(SystemModuleUsr.modules(in: "s:Si"), ["Swift"])
        XCTAssertEqual(SystemModuleUsr.modules(in: "s:So8NSBundleC"), [])
        XCTAssertEqual(SystemModuleUsr.modules(in: "c:objc(cs)NSView"), [])
    }

    // MARK: - Private

    private func indexFixtures(enableUnusedSystemImports: Bool) {
        let configuration = Configuration()
        configuration.enableUnusedSystemImports = enableUnusedSystemImports
        index(
            sourceFiles: Self.fixtureFiles.map { Self.fixtureDirectory.appending($0) },
            configuration: configuration
        )
    }
}
