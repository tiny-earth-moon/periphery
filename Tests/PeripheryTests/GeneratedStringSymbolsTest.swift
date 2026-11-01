import Configuration
@testable import Indexer
import Logger
import SourceGraph
@testable import SyntaxAnalysis
import SystemPackage
import XCTest

final class GeneratedStringSymbolsTest: XCTestCase {
    func testMapsGeneratedSymbolLinesToKeys() {
        let source = """
        import Foundation

        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        nonisolated extension LocalizedStringResource {
            static func generatedCount(_ arg1: Int) -> LocalizedStringResource {
                LocalizedStringResource("generated.count %lld", defaultValue: "\\(arg1, specifier: "%lld")", table: "Localizable", bundle: resourceBundleDescription)
            }

            static var generatedUsed: LocalizedStringResource {
                LocalizedStringResource("generated.used", table: "Localizable", bundle: resourceBundleDescription)
            }

            var notGenerated: String { "not.a.key" }
        }
        """

        XCTAssertEqual(GeneratedStringSymbols.keys(in: source), [5: "generated.count %lld", 9: "generated.used"])
    }

    func testReadsExtendingModuleFromUsr() {
        XCTAssertEqual(
            GeneratedStringSymbolsIndexer.extendingModule(ofUsr: "s:10Foundation23LocalizedStringResourceV14SwiftUIProjectE13generatedUsedACvpZ"),
            "SwiftUIProject"
        )
        XCTAssertNil(GeneratedStringSymbolsIndexer.extendingModule(ofUsr: "s:10Foundation23LocalizedStringResourceV5tableSSSgvp"))
        XCTAssertNil(GeneratedStringSymbolsIndexer.extendingModule(ofUsr: "s:7SwiftUI4TextV"))
    }

    func testDoesNotRetainCataloguesWhenGeneratedSourceIsMissing() throws {
        let graph = SourceGraph(configuration: Configuration(), logger: logger)
        let location = Location(file: SourceFile(path: FilePath("/tmp/App/View.swift"), modules: ["Client"]), line: 1, column: 1)
        graph.add(Reference(
            name: "ownerTitle",
            kind: .normal,
            declarationKind: .varStatic,
            usr: "s:10Foundation23LocalizedStringResourceV5OwnerE10ownerTitleACvpZ",
            location: location
        ))
        let mutex = SourceGraphMutex(graph: graph)

        try GeneratedStringSymbolsIndexer(files: [:], graph: mutex, logger: logger.contextualized(with: "test")).perform()

        XCTAssertEqual(graph.runtimeLocalizedStringKeyPrefixesByModule, [:])
        XCTAssertEqual(graph.runtimeLocalizedStringKeyPrefixes, [])
    }

    // MARK: - Private

    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)
}
