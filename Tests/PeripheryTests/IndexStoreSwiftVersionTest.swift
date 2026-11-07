import Configuration
import Foundation
import Logger
@testable import Shared
@testable import SourceGraph
@testable import SyntaxAnalysis
import SystemPackage
import XCTest

/// Toolchain workarounds follow the compiler that produced the index store units, not the `swift` found on PATH.
final class IndexStoreSwiftVersionTest: XCTestCase {
    private let pathSwift64 = "swift-driver version: 1.168.6 Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1)"
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never).contextualized(with: "test")

    func testUnitProducedBySwift62TakesTheGenericExtensionWorkaroundEvenWhenPathSwiftIs64() throws {
        let swiftVersion = try SwiftVersion(fullVersion: pathSwift64)
            .producingIndexUnits(withProviderVersions: ["6.2.3"], logger: logger, context: "test")

        XCTAssertEqual(swiftVersion.version, "6.4.2")
        XCTAssertEqual(swiftVersion.indexStoreVersion, "6.2.3")
        XCTAssertEqual(try genericExtensionColumn(swiftVersion: swiftVersion), Self.rightAngleColumn)
    }

    func testUnitProducedBySwift64SkipsTheGenericExtensionWorkaround() throws {
        let swiftVersion = try SwiftVersion(fullVersion: pathSwift64)
            .producingIndexUnits(withProviderVersions: ["Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9)"], logger: logger, context: "test")

        XCTAssertEqual(swiftVersion.indexStoreVersion, "6.4.2")
        XCTAssertEqual(try genericExtensionColumn(swiftVersion: swiftVersion), Self.nameColumn)
    }

    func testUnitWithoutProviderVersionFallsBackToPathSwift() throws {
        let swiftVersion = try SwiftVersion(fullVersion: pathSwift64)
            .producingIndexUnits(withProviderVersions: ["", "not a version"], logger: logger, context: "test")

        XCTAssertEqual(swiftVersion.indexStoreVersion, "6.4.2")
    }

    func testNoUnitKeepsPathSwift() throws {
        let swiftVersion = try SwiftVersion(fullVersion: pathSwift64)
            .producingIndexUnits(withProviderVersions: [], logger: logger, context: "test")

        XCTAssertEqual(swiftVersion.indexStoreVersion, "6.4.2")
    }

    func testDisagreeingUnitsGateOnTheOldestProducer() throws {
        let swiftVersion = try SwiftVersion(fullVersion: pathSwift64)
            .producingIndexUnits(withProviderVersions: ["6.4.2", "6.2.10", "6.3"], logger: logger, context: "test")

        XCTAssertEqual(swiftVersion.indexStoreVersion, "6.2.10")
    }

    func testUnitWithoutProviderVersionCountsAsPathSwiftAmongDisagreeingUnits() throws {
        let swiftVersion = try SwiftVersion(fullVersion: "Apple Swift version 6.2.1 (swiftlang-6.2.1)")
            .producingIndexUnits(withProviderVersions: ["6.4.2", ""], logger: logger, context: "test")

        XCTAssertEqual(swiftVersion.indexStoreVersion, "6.2.1")
    }

    func testStringInterpolationRetainerFollowsTheIndexStoreVersion() throws {
        let configuration = Configuration()
        let pathSwift = try SwiftVersion(fullVersion: pathSwift64)

        XCTAssertTrue(try appendInterpolationIsRetained(
            swiftVersion: pathSwift.producingIndexUnits(withProviderVersions: ["6.2.3"], logger: logger, context: "test"),
            configuration: configuration
        ))
        XCTAssertFalse(try appendInterpolationIsRetained(
            swiftVersion: pathSwift.producingIndexUnits(withProviderVersions: ["6.4.2"], logger: logger, context: "test"),
            configuration: configuration
        ))
    }

    // MARK: - Private

    private static let source = "extension Box<Int> {}\n"
    private static let nameColumn = 11
    private static let rightAngleColumn = 18

    private func genericExtensionColumn(swiftVersion: SwiftVersion) throws -> Int? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("index-store-swift-version-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Box.swift")
        try Self.source.write(to: url, atomically: true, encoding: .utf8)

        let file = SourceFile(path: FilePath(url.path), modules: ["Fixture"])
        let multiplexingVisitor = try MultiplexingSyntaxVisitor(file: file, swiftVersion: swiftVersion)
        let visitor = multiplexingVisitor.add(DeclarationSyntaxVisitor.self)
        multiplexingVisitor.visit()

        return visitor.results.first?.location.column
    }

    private func appendInterpolationIsRetained(swiftVersion: SwiftVersion, configuration: Configuration) throws -> Bool {
        let graph = SourceGraph(configuration: configuration, logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let file = SourceFile(path: FilePath("Sources/Fixture/Interpolation.swift"), modules: ["Fixture"])
        let extensionDeclaration = Declaration(name: "Interpolation", kind: .extensionStruct, usrs: ["s:e:Interpolation"], location: Location(file: file, line: 1, column: 1))
        let function = Declaration(name: "appendInterpolation(_:)", kind: .functionMethodInstance, usrs: ["s:appendInterpolation"], location: Location(file: file, line: 2, column: 5))
        function.parent = extensionDeclaration
        extensionDeclaration.declarations.insert(function)
        graph.add(extensionDeclaration)
        graph.add(function)

        StringInterpolationAppendInterpolationRetainer(graph: graph, configuration: configuration, swiftVersion: swiftVersion).mutate()

        return graph.isRetained(function)
    }
}
