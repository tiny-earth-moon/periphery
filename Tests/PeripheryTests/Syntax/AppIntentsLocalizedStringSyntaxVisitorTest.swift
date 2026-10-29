import Foundation
import Logger
import Shared
@testable import SourceGraph
@testable import SyntaxAnalysis
import SystemPackage
@testable import TestShared
import XCTest

final class AppIntentsLocalizedStringSyntaxVisitorTest: XCTestCase {
    func testRecognisesAppIntentsTypesAsLocalized() {
        for name in ["ParameterSummaryString", "IntentDialog", "AppShortcutPhrase", "IntentDescription", "DisplayRepresentation", "LocalizedStringResource"] {
            XCTAssertTrue(LocalizedStringSyntaxVisitor.isLocalizedType("AppIntents.\(name)"), name)
        }
    }

    func testDetectsParameterAttributeKeys() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        struct Intent {
            @Parameter(title: "parameter_title_key", description: "parameter_description_key", requestValueDialog: "parameter_dialog_key")
            var name: String
            @Parameter(title: "defaulted_title_key", default: "not_a_key")
            var other: String
            @Property(title: "property_title_key")
            var property: String
            @Other(title: "other_attribute_key")
            var unrelated: String
        }
        """)

        XCTAssertEqual(usedKeys, [
            "parameter_title_key", "parameter_description_key", "parameter_dialog_key",
            "defaulted_title_key", "property_title_key",
        ])
    }

    func testRecordsAppIntentsCallSites() throws {
        let callSites = try collectCallSites(from: """
        Summary("summary_key") { \\.$name }
        When(\\.$flag, .equalTo, true) { Summary("when_key") } otherwise: { Summary("otherwise_key") }
        .result(dialog: "dialog_key")
        TypeDisplayRepresentation(name: "type_name_key")
        DisplayRepresentation(title: "display_title_key", subtitle: "display_subtitle_key")
        AppShortcut(intent: Intent(), phrases: ["phrase_key"], shortTitle: "short_title_key", systemImageName: "star")
        """)

        XCTAssertEqual(Set(callSites.flatMap(\.allKeys)), [
            "summary_key", "when_key", "otherwise_key", "dialog_key", "type_name_key",
            "display_title_key", "display_subtitle_key", "phrase_key", "short_title_key", "star",
        ])
    }

    func testRetainsAppIntentsDeclarationKeys() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        struct Intent {
            static let title: LocalizedStringResource = "title_key"
            static let description: IntentDescription = "description_key"
            static let dialog: IntentDialog = "dialog_key"
        }
        """)

        XCTAssertEqual(usedKeys, ["title_key", "description_key", "dialog_key"])
    }

    // MARK: - Private

    private func collectCallSites(from source: String) throws -> [LocalizedStringCallSite] {
        try visit(source).callSites
    }

    private func collectUsedStringKeys(from source: String) throws -> Set<String> {
        try visit(source).usedStringKeys
    }

    private func visit(_ source: String) throws -> LocalizedStringSyntaxVisitor {
        // Create a temporary file with the source
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpFile = tmpDir.appendingPathComponent("LocalizedStringTest-\(UUID().uuidString).swift")
        try source.write(to: tmpFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        let path = FilePath(tmpFile.path)
        let sourceFile = SourceFile(path: path, modules: ["Test"])

        let shell = ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let swiftVersion = SwiftVersion(shell: shell)
        let multiplexingVisitor = try MultiplexingSyntaxVisitor(file: sourceFile, swiftVersion: swiftVersion)
        let visitor = multiplexingVisitor.add(LocalizedStringSyntaxVisitor.self)
        multiplexingVisitor.visit()

        return visitor
    }
}
