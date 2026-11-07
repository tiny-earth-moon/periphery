import Configuration
import Foundation
@testable import Frontend
import SystemPackage
@testable import TestShared
import XCTest

/// Ties together the settings of the configuration file, the options of `scan`, the documentation and the committed
/// JSON Schema, so that an option added on one side only fails here.
final class ConfigurationSchemaTest: XCTestCase {
    /// `scan` options that have no key in the configuration file.
    private static let commandLineOnlyOptions: Set = ["config", "project_root", "setup", "explain", "no_color", "removed_bazel_options"]
    /// Keys that have no `scan` option.
    private static let configurationFileOnlyKeys: Set = ["xcode_list_arguments"]
    /// `scan` options whose key in the configuration file has another name.
    private static let renamedOptions = ["relative_to": "relative_results_base"]

    func testSchemaHasOnePropertyPerSettingInSettingsOrder() throws {
        let schema = try generatedSchema()
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])

        XCTAssertEqual(Set(properties.keys), Set(Configuration().settingKeys))
        XCTAssertEqual(Configuration().settingKeys.count, Set(Configuration().settingKeys).count, "duplicate setting key")

        let text = Configuration().jsonSchema()
        let offsets = Configuration().settingKeys.map { text.range(of: "\n    \"\($0)\": {")?.lowerBound }
        XCTAssertFalse(offsets.contains(nil))
        XCTAssertEqual(offsets.compactMap(\.self), offsets.compactMap(\.self).sorted(), "properties are not in the order of 'settings'")
    }

    func testEverySchemaPropertyHasADescriptionAndAType() throws {
        let properties = try XCTUnwrap(generatedSchema()["properties"] as? [String: [String: Any]])

        for (key, property) in properties {
            XCTAssertFalse((property["description"] as? String ?? "").isEmpty, "\(key) has no description")
            XCTAssertTrue(property["type"] != nil || property["oneOf"] != nil, "\(key) has no type")
        }
    }

    func testSchemaListsTheCasesOfFormatAndColorAndRejectsUnknownKeys() throws {
        let schema = try generatedSchema()
        let properties = try XCTUnwrap(schema["properties"] as? [String: [String: Any]])

        XCTAssertEqual(schema["$schema"] as? String, "http://json-schema.org/draft-07/schema#")
        XCTAssertEqual(schema["$id"] as? String, "https://raw.githubusercontent.com/tiny-earth-moon/outskirts/master/outskirts.schema.json")
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual(properties["format"]?["enum"] as? [String], OutputFormat.allCases.map(\.rawValue))
        XCTAssertEqual(properties["format"]?["default"] as? String, "xcode")
        XCTAssertEqual(properties["color"]?["enum"] as? [String], ColorOption.allCases.map(\.rawValue))
        XCTAssertEqual(properties["strict"]?["type"] as? String, "boolean")
        XCTAssertEqual(properties["cache_max_age_days"]?["default"] as? Int, 14)
        XCTAssertEqual(properties["project"]?["type"] as? String, "string")
        XCTAssertNotNil(properties["report_exclude"]?["oneOf"])
    }

    func testSettingsMatchTheScanOptions() throws {
        let command = try ScanCommand.parse([])
        let groups: [Any] = [
            command,
            command.projectOptions,
            command.buildOptions,
            command.analysisOptions,
            command.retentionOptions,
            command.resultsOptions,
            command.baselineOptions,
            command.localizedStringOptions,
            command.miscellaneousOptions,
        ]
        let labels = groups.flatMap { Mirror(reflecting: $0).children.compactMap(\.label) }.filter { !$0.hasSuffix("Options") }
        let optionKeys = labels.map { label in
            let key = Self.snakeCased(String(label.drop { $0 == "_" }))
            return Self.renamedOptions[key] ?? key
        }

        let settingKeys = Set(Configuration().settingKeys).subtracting(Self.configurationFileOnlyKeys)
        let scanKeys = Set(optionKeys).subtracting(Self.commandLineOnlyOptions)

        XCTAssertEqual(settingKeys.subtracting(scanKeys).sorted(), [], "settings without a scan option")
        XCTAssertEqual(scanKeys.subtracting(settingKeys).sorted(), [], "scan options without a setting")
    }

    /// Every setting has its entry in docs/options.md, with its description and default, and every `scan` option its
    /// heading, so that the reference is never out of step with the schema or the help.
    func testOptionsReferenceIsUpToDate() throws {
        let reference = try Documentation.page("options")
        let lines = reference.split(separator: "\n").map(String.init)
        let properties = try XCTUnwrap(generatedSchema()["properties"] as? [String: [String: Any]])
        let stale = "docs/options.md is out of date: run 'npm run sync' in site/"

        for (key, property) in properties {
            let facts = lines.first { $0.hasPrefix("Key `\(key)`") }
            XCTAssertNotNil(facts, "\(key) has no entry. \(stale)")

            let description = try XCTUnwrap(property["description"] as? String)
                .replacing(#/\s*\(command line: --[a-z-]+\)/#, with: "")
            XCTAssertTrue(reference.contains(description), "the description of \(key) changed. \(stale)")

            if let value = property["default"], !(value is [Any]) {
                let json = try XCTUnwrap(String(bytes: JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed), encoding: .utf8))
                let shown = json.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                XCTAssertTrue(facts?.contains("default `\(shown)`") == true, "the default of \(key) changed. \(stale)")
            }
        }

        let flags = ScanCommand.helpMessage(columns: 1000).split(separator: "\n").compactMap { line in
            line.firstMatch(of: #/^\s+(?:-[A-Za-z], )?(--[a-z][a-z-]*)/#).map { String($0.1) }
        }
        XCTAssertFalse(flags.isEmpty)
        for flag in flags where flag != "--help" {
            XCTAssertTrue(lines.contains("### `\(flag)`"), "\(flag) has no entry. \(stale)")
        }
    }

    func testCommittedSchemaIsTheGeneratedOne() throws {
        let committed = try String(contentsOfFile: ProjectRootPath.appending("outskirts.schema.json").string, encoding: .utf8)

        XCTAssertEqual(committed, Configuration().jsonSchema(), "outskirts.schema.json is out of date, regenerate it with 'outskirts config schema > outskirts.schema.json'")
    }

    func testExamplesStartWithTheSchemaCommentAndLoadWithoutWarnings() throws {
        let directory = ProjectRootPath.appending("examples").string
        let files = try FileManager.default.contentsOfDirectory(atPath: directory).filter { $0.hasSuffix(".yml") }
        XCTAssertFalse(files.isEmpty)

        for file in files {
            let path = FilePath(directory).appending(file)
            let contents = try String(contentsOfFile: path.string, encoding: .utf8)
            XCTAssertEqual(contents.split(separator: "\n").first.map(String.init), Configuration.schemaComment, file)

            var warnings: [String] = []
            try Configuration().load(from: path) { warnings.append($0) }
            XCTAssertEqual(warnings, [], file)
        }
    }

    func testSavedConfigurationStartsWithTheSchemaComment() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("outskirts-schema-\(UUID().uuidString).yml")
        defer { try? FileManager.default.removeItem(at: file) }
        let configuration = Configuration()
        configuration.strict = true

        try configuration.save(to: FilePath(file.path))

        let contents = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(contents, "\(Configuration.schemaComment)\nstrict: true\n")
    }

    // MARK: - Private

    private func generatedSchema() throws -> [String: Any] {
        let data = Data(Configuration().jsonSchema().utf8)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// `noRetainSPI` is `no_retain_spi`, `retainSwiftUIPreviews` is `retain_swift_ui_previews`.
    private static func snakeCased(_ name: String) -> String {
        let characters = Array(name)
        var result = ""

        for (index, character) in characters.enumerated() {
            if character.isUppercase, index > 0 {
                let previousIsLower = characters[index - 1].isLowercase
                let nextIsLower = index + 1 < characters.count && characters[index + 1].isLowercase
                if previousIsLower || (characters[index - 1].isUppercase && nextIsLower) {
                    result += "_"
                }
            }
            result += character.lowercased()
        }

        return result
    }
}
