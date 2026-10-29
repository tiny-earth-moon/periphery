import Foundation
import Logger
import Shared
@testable import SourceGraph
@testable import SyntaxAnalysis
import SystemPackage
@testable import TestShared
import XCTest

final class LocalizedStringSyntaxVisitorTest: XCTestCase {
    func testDetectsNSLocalizedString() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let greeting = NSLocalizedString("hello_world", comment: "")
        let farewell = NSLocalizedString("goodbye", tableName: "Other", comment: "")
        """)

        XCTAssertEqual(usedKeys, ["hello_world", "goodbye"])
    }

    func testDetectsStringLocalized() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let greeting = String(localized: "welcome_message")
        let farewell = String(localized: "farewell_message", table: "Main")
        """)

        XCTAssertEqual(usedKeys, ["welcome_message", "farewell_message"])
    }

    func testDetectsLocalizedStringKey() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let key = LocalizedStringKey("settings_title")
        """)

        XCTAssertEqual(usedKeys, ["settings_title"])
    }

    func testDetectsLocalizedStringResource() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let resource = LocalizedStringResource("resource_key")
        """)

        XCTAssertEqual(usedKeys, ["resource_key"])
    }

    func testDetectsSwiftUIText() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        Text("button_label")
        """)

        XCTAssertEqual(usedKeys, ["button_label"])
    }

    func testDetectsBundleLocalizedString() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        Bundle.main.localizedString(forKey: "bundle_key", value: nil, table: nil)
        """)

        XCTAssertEqual(usedKeys, ["bundle_key"])
    }

    func testNormalizesStringInterpolationsToFormatKeys() throws {
        let usedKeys = try collectUsedStringKeys(from: ##"""
        let greeting = NSLocalizedString("hello \(name)", comment: "")
        Text("count \(42) items")
        Text("ratio \(0.5) and \(-3)")
        Text("progress \(value, specifier: "%.1f") at 100%")
        Text(#"raw \#(name) \n"#)
        """##)

        XCTAssertEqual(usedKeys, [
            "hello %@", "count %lld items", "ratio %lf and %lld", "progress %.1f at 100%%", #"raw %@ \n"#,
        ])
    }

    func testMultipleKeys() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        NSLocalizedString("key1", comment: "")
        String(localized: "key2")
        Text("key3")
        LocalizedStringKey("key4")
        """)

        XCTAssertEqual(usedKeys, ["key1", "key2", "key3", "key4"])
    }

    func testResolvesEscapeSequences() throws {
        let usedKeys = try collectUsedStringKeys(from: #"""
        Text("line_one\nline_two")
        String(localized: "quoted \"key\"")
        NSLocalizedString(#"raw\key"#, comment: "")
        """#)

        XCTAssertEqual(usedKeys, ["line_one\nline_two", "quoted \"key\"", #"raw\key"#])
    }

    func testIgnoresTextVerbatim() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        Text(verbatim: "not_a_key")
        """)

        XCTAssertEqual(usedKeys, [])
    }

    func testIgnoresUnsupportedForms() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let key = "dynamic_key"
        String(localized: .generatedSymbolKey)
        Text(.generatedSymbolKey)
        String(localized: String.LocalizationValue(key))
        NSLocalizedString(key, comment: "")
        Text(key)
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        """)

        XCTAssertEqual(usedKeys, [])
    }

    func testTableAndBundleArgumentsDoNotPreventDetection() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        String(localized: "table_key", table: "Other", bundle: .module)
        Text("text_table_key", tableName: "Other", bundle: .module)
        """)

        XCTAssertEqual(usedKeys, ["table_key", "text_table_key"])
    }

    func testDetectsLiteralsOfLocalizedDeclarationTypes() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let key: LocalizedStringKey = "annotated_key"
        let plain: String = "plain_key"
        var resource: LocalizedStringResource { condition ? "computed_true_key" : "computed_false_key" }
        func title() -> String.LocalizationValue {
            if value == "condition_key" { return "returned_key" }
            return format("argument_key")
        }
        func row(title: LocalizedStringKey = "default_key", detail: String = "string_default_key") {}
        """)

        XCTAssertEqual(usedKeys, [
            "annotated_key", "computed_true_key", "computed_false_key", "returned_key", "default_key",
        ])
    }

    func testDetectsLiteralsReturnedFromSwitchAndIf() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        static func graphicsKey(_ quality: Quality) -> LocalizedStringKey {
            switch quality {
            case .auto: "switch_auto_key"
            case .low: return "switch_low_key"
            }
        }
        var stageKey: LocalizedStringResource? {
            if isFirst { "if_true_key" } else { "if_false_key" }
        }
        let title: LocalizedStringKey = switch mode {
        case .compact: "switch_expression_key"
        default: "switch_default_key"
        }
        func plain() -> String {
            switch mode { case .compact: "plain_switch_key" }
        }
        """)

        XCTAssertEqual(usedKeys, [
            "switch_auto_key", "switch_low_key", "if_true_key", "if_false_key", "switch_expression_key",
            "switch_default_key",
        ])
    }

    func testDetectsLiteralsReturnedFromClosures() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let label: (Int) -> LocalizedStringKey = { count in count == 0 ? "closure_empty_key" : "closure_count_key \\(count)" }
        let lazyTitle: LocalizedStringKey = { "applied_closure_key" }()
        let plain: () -> String = { "plain_closure_key" }
        """)

        XCTAssertEqual(usedKeys, ["closure_empty_key", "closure_count_key %@", "applied_closure_key"])
    }

    func testDetectsTernaries() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        static func valueKey(remaining: Int) -> LocalizedStringKey {
            remaining == 0 ? "ternary_empty_key" : "ternary_value_key \\(remaining)"
        }
        Text(isOn ? "text_on_key" : "text_off_key")
        String(localized: isOn ? "localized_on_key" : "localized_off_key")
        """)

        XCTAssertEqual(usedKeys, [
            "ternary_empty_key", "ternary_value_key %@", "text_on_key", "text_off_key", "localized_on_key",
            "localized_off_key",
        ])
    }

    func testDetectsTypedArrayDictionaryAndTupleElements() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        let array: [LocalizedStringResource] = ["array_key", "array_other_key"]
        static let labels: [Pose: String.LocalizationValue] = [.standing: "dictionary_value_key"]
        static let symbols: [String: LocalizedStringKey] = ["dictionary_string_key": "dictionary_localized_key"]
        let options: [(LocalizedStringKey, Int)] = [("tuple_array_key", 1)]
        let pair: (title: LocalizedStringKey, symbol: String) = (title: "tuple_key", symbol: "tuple_symbol_key")
        let optionalArray: [LocalizedStringKey]? = ["optional_array_key"]
        """)

        XCTAssertEqual(usedKeys, [
            "array_key", "array_other_key", "dictionary_value_key", "dictionary_localized_key", "tuple_array_key",
            "tuple_key", "optional_array_key",
        ])
    }

    func testRecordsTupleAndClosureArgumentsOfCallSites() throws {
        let callSites = try collectCallSites(from: """
        row(title: ("tuple_argument_key"), make: { "closure_argument_key" })
        """)

        XCTAssertEqual(callSites.first?.arguments, [
            .init(label: "title", keys: ["tuple_argument_key"]),
            .init(label: "make", keys: ["closure_argument_key"]),
        ])
    }

    func testRecordsCallSitesForResolution() throws {
        let callSites = try collectCallSites(from: """
        Button("button_key") {}
        view.navigationTitle(isPrimary ? "primary_key" : "secondary_key")
        Label("label_key", systemImage: "star")
        Button(action: {}) { Text(verbatim: name) }
        """)

        XCTAssertEqual(callSites.map(\.line), [1, 2, 3])
        XCTAssertEqual(callSites.map(\.column), [1, 6, 1])
        XCTAssertEqual(callSites[0].arguments, [.init(label: nil, keys: ["button_key"])])
        XCTAssertEqual(callSites[1].arguments, [.init(label: nil, keys: ["primary_key", "secondary_key"])])
        XCTAssertEqual(callSites[2].arguments, [
            .init(label: nil, keys: ["label_key"]),
            .init(label: "systemImage", keys: ["star"]),
        ])
    }

    func testRetainsLiteralsPassedToUnlocatableCallees() throws {
        let usedKeys = try collectUsedStringKeys(from: """
        makeFormatter()("closure_key")
        """)

        XCTAssertEqual(usedKeys, ["closure_key"])
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
