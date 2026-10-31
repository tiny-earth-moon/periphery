import Foundation
import Logger
import Shared
import SystemPackage
@testable import XcodeSupport
import XCTest

final class XcodebuildIndexStoreTest: XCTestCase {
    private var root: FilePath!
    private var xcodebuild: Xcodebuild!
    private var project: XcodeProject!

    override func setUpWithError() throws {
        let shell = ShellMock(output: "Xcode 0.0")
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let tmp = FilePath(NSTemporaryDirectory()).appending("periphery-index-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: tmp.string, withIntermediateDirectories: true)
        root = tmp
        xcodebuild = Xcodebuild(shell: shell, logger: logger)
        var loaded: Set<FilePath> = []
        project = try XcodeProject(path: UIKitProjectPath, loadedProjectPaths: &loaded, xcodebuild: xcodebuild, shell: shell, logger: logger)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root.string)
    }

    private var projectName: String {
        project.path.lexicallyNormalized().lastComponent?.stem ?? ""
    }

    @discardableResult
    private func makeDataStore(in folder: String, modified: Date) throws -> FilePath {
        let store = root.appending(folder).appending("Index.noindex/DataStore")
        try FileManager.default.createDirectory(atPath: store.string, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: store.string)
        return store
    }

    func testSkippedBuildFallsBackToMostRecentXcodeDerivedData() throws {
        try makeDataStore(in: "\(projectName)-old", modified: Date(timeIntervalSince1970: 1000))
        let newest = try makeDataStore(in: "\(projectName)-new", modified: Date(timeIntervalSince1970: 2000))
        try makeDataStore(in: "\(projectName)Other-zzz", modified: Date(timeIntervalSince1970: 3000))

        let path = try xcodebuild.indexStorePath(project: project, schemes: [], skipBuild: true, xcodeDerivedDataRoot: root)

        XCTAssertEqual(path, newest)
    }

    func testSkippedBuildWithoutAnyIndexStoreListsTriedPaths() throws {
        XCTAssertThrowsError(
            try xcodebuild.indexStorePath(project: project, schemes: [], skipBuild: true, xcodeDerivedDataRoot: root)
        ) { error in
            guard case let PeripheryError.indexStoreNotFoundAfterSkippedBuild(tried) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertTrue(tried.contains { $0.contains("DerivedData-") })
            XCTAssertTrue(tried.contains { $0.hasPrefix(root.string) && $0.contains("\(projectName)-*") })
        }
    }

    func testBuildNotSkippedDoesNotFallBackToXcodeDerivedData() throws {
        try makeDataStore(in: "\(projectName)-abc", modified: Date())

        XCTAssertThrowsError(
            try xcodebuild.indexStorePath(project: project, schemes: [], skipBuild: false, xcodeDerivedDataRoot: root)
        ) { error in
            guard case PeripheryError.indexStoreNotFound = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
