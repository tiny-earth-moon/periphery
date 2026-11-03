import Configuration
import Foundation
import Shared
import SystemPackage
import XCTest

final class ConfigurationLoadTest: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-config-load-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // MARK: - Booleans

    func testYamlBooleansProduceNoWarning() throws {
        let (configuration, warnings, _) = try load("""
        strict: true
        retain_public: false
        superfluous_ignore_comments: false
        """)

        XCTAssertEqual(warnings, [])
        XCTAssertTrue(configuration.strict)
        XCTAssertFalse(configuration.retainPublic)
        XCTAssertFalse(configuration.superfluousIgnoreComments)
    }

    func testQuotedBooleanIsAcceptedWithAWarning() throws {
        let (configuration, warnings, file) = try load("""
        strict: "true"
        superfluous_ignore_comments: "false"
        """)

        XCTAssertTrue(configuration.strict)
        XCTAssertFalse(configuration.superfluousIgnoreComments)
        XCTAssertEqual(warnings, [
            "\(file): 'strict' expects a boolean, got the string \"true\"; treating it as true",
            "\(file): 'superfluous_ignore_comments' expects a boolean, got the string \"false\"; treating it as false",
        ])
    }

    func testIntegerForBooleanWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("strict: 1\n")

        XCTAssertFalse(configuration.strict)
        XCTAssertEqual(warnings, ["\(file): 'strict' expects a boolean, got the integer 1"])
    }

    func testUnrecognizedStringForBooleanWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("""
        retain_public: "yes please"
        retain_assign_only_properties: maybe
        """)

        XCTAssertFalse(configuration.retainPublic)
        XCTAssertFalse(configuration.retainAssignOnlyProperties)
        XCTAssertEqual(warnings, [
            "\(file): 'retain_assign_only_properties' expects a boolean, got the string \"maybe\"",
            "\(file): 'retain_public' expects a boolean, got the string \"yes please\"",
        ])
    }

    func testBooleanDefaultingToTrueKeepsItOnAWrongType() throws {
        let (configuration, warnings, _) = try load("superfluous_ignore_comments: 0\n")

        XCTAssertTrue(configuration.superfluousIgnoreComments)
        _ = try onlyWarning(warnings)
    }

    // MARK: - Enums

    func testInvalidEnumValuesWarnOnceAndKeepTheDefault() throws {
        for value in ["xml", "JSON", "jsno"] {
            let (configuration, warnings, file) = try load("format: \(value)\n")

            XCTAssertEqual(configuration.outputFormat, .xcode, value)
            XCTAssertEqual(
                warnings,
                ["\(file): 'format' has invalid value '\(value)' (expected one of xcode, csv, json, checkstyle, codeclimate, github-actions, github-markdown, gitlab-codequality, sarif); using default 'xcode'"],
                value
            )
        }
    }

    func testInvalidColorWarnsOnceAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("color: purple\n")

        XCTAssertEqual(configuration.color, .auto)
        XCTAssertEqual(warnings, ["\(file): 'color' has invalid value 'purple' (expected one of auto, always, never); using default 'auto'"])
    }

    func testValidEnumValuesProduceNoWarning() throws {
        let (configuration, warnings, _) = try load("""
        format: github-actions
        color: never
        """)

        XCTAssertEqual(warnings, [])
        XCTAssertEqual(configuration.outputFormat, .githubActions)
        XCTAssertEqual(configuration.color, .never)
    }

    func testNonStringForEnumWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, _) = try load("format: 1\n")

        XCTAssertEqual(configuration.outputFormat, .xcode)
        let warning = try onlyWarning(warnings)
        XCTAssertTrue(warning.contains("'format' expects one of xcode, csv"), warning)
        XCTAssertTrue(warning.hasSuffix("got the integer 1"), warning)
    }

    // MARK: - Lists

    func testScalarForAListSettingIsWrapped() throws {
        let (configuration, warnings, _) = try load("""
        exclude_targets: Demo
        retain_files: "**/Unused.swift"
        index_store_path: .build/out
        report_exclude: "**/Generated/*.swift"
        index_exclude: "**/Vendor/**"
        """)

        XCTAssertEqual(warnings, [])
        XCTAssertEqual(configuration.excludeTargets, ["Demo"])
        XCTAssertEqual(configuration.retainFiles, ["**/Unused.swift"])
        XCTAssertEqual(configuration.indexStorePath, [FilePath(".build/out")])
        XCTAssertEqual(configuration.reportExclude, [.pattern("**/Generated/*.swift")])
        XCTAssertTrue(configuration.indexExclude.contains("**/Vendor/**"))
        XCTAssertTrue(configuration.indexExclude.contains("**/SourcePackages/checkouts/**"))
    }

    func testEveryStringListSettingAcceptsAScalar() throws {
        let keys = [
            "schemes", "exclude_targets", "index_exclude", "report_include", "build_arguments", "xcode_list_arguments",
            "retain_assign_only_property_types", "external_encodable_protocols", "external_codable_protocols",
            "external_test_case_classes", "retain_files", "no_retain_spi", "localized_string_catalog_exclude",
            "localized_string_key_patterns", "retain_unused_imported_modules", "retain_attributes",
        ]

        for key in keys {
            let (configuration, warnings, _) = try load("\(key): value\n")
            XCTAssertEqual(warnings, [], key)
            XCTAssertTrue(try configuration.asYaml().contains("value"), key)
        }
    }

    func testListWithANonStringElementWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("schemes: [App, 2024]\n")

        XCTAssertEqual(configuration.schemes, [])
        XCTAssertEqual(warnings, ["\(file): 'schemes' expects a list of strings, got a list containing the integer 2024"])
    }

    func testMappingForAListSettingWarns() throws {
        let (configuration, warnings, _) = try load("""
        retain_files:
          a: b
        """)

        XCTAssertEqual(configuration.retainFiles, [])
        let warning = try onlyWarning(warnings)
        XCTAssertTrue(warning.contains("'retain_files' expects a list of strings, got a mapping"), warning)
    }

    func testInvalidReportExcludeWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, _) = try load("report_exclude: 5\n")

        XCTAssertEqual(configuration.reportExclude, [])
        let warning = try onlyWarning(warnings)
        XCTAssertTrue(warning.contains("'report_exclude' expects"), warning)
        XCTAssertTrue(warning.hasSuffix("got the integer 5"), warning)
    }

    // MARK: - Strings and integers

    func testIntegerForAStringSettingWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("""
        project: 5
        baseline: true
        """)

        XCTAssertNil(configuration.project)
        XCTAssertNil(configuration.baseline)
        XCTAssertEqual(warnings, [
            "\(file): 'baseline' expects a string, got the boolean true",
            "\(file): 'project' expects a string, got the integer 5",
        ])
    }

    func testQuotedNumberForAnIntegerSettingWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("cache_max_age_days: \"7\"\n")

        XCTAssertEqual(configuration.cacheMaxAgeDays, 14)
        XCTAssertEqual(warnings, ["\(file): 'cache_max_age_days' expects an integer, got the string \"7\""])
    }

    func testFractionForAnIntegerSettingWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("cache_max_age_days: 7.5\n")

        XCTAssertEqual(configuration.cacheMaxAgeDays, 14)
        XCTAssertEqual(warnings, ["\(file): 'cache_max_age_days' expects an integer, got the number 7.5"])
    }

    func testIntegerForAnIntegerSettingProducesNoWarning() throws {
        let (configuration, warnings, _) = try load("cache_max_age_days: 7\n")

        XCTAssertEqual(warnings, [])
        XCTAssertEqual(configuration.cacheMaxAgeDays, 7)
    }

    func testNullValueWarnsAndKeepsTheDefault() throws {
        let (configuration, warnings, file) = try load("strict:\n")

        XCTAssertFalse(configuration.strict)
        XCTAssertEqual(warnings, ["\(file): 'strict' expects a boolean, got null"])
    }

    // MARK: - Document and keys

    func testNonMappingDocumentThrows() throws {
        for yaml in ["- a\n- b\n", "just a string\n", "42\n"] {
            let file = try write(yaml)

            XCTAssertThrowsError(try Configuration().load(from: file), yaml) { error in
                XCTAssertTrue(
                    error.localizedDescription.hasPrefix("\(file.string): the configuration must be a mapping of keys to values, got"),
                    error.localizedDescription
                )
            }
        }
    }

    func testEmptyDocumentLoadsTheDefaults() throws {
        for yaml in ["", "# nothing but a comment\n"] {
            let (configuration, warnings, _) = try load(yaml)

            XCTAssertEqual(warnings, [], yaml)
            XCTAssertFalse(configuration.hasNonDefaultValues, yaml)
        }
    }

    func testMisspeltKeyGetsASuggestion() throws {
        let (_, warnings, file) = try load("retain_pubic: true\n")

        XCTAssertEqual(warnings, ["\(file): invalid key 'retain_pubic' (did you mean 'retain_public'?)"])
    }

    func testKeyWrittenWithDashesOrCapitalsGetsASuggestion() throws {
        let (_, warnings, file) = try load("""
        retain-public: true
        Strict: true
        """)

        XCTAssertEqual(warnings, [
            "\(file): invalid key 'Strict' (did you mean 'strict'?)",
            "\(file): invalid key 'retain-public' (did you mean 'retain_public'?)",
        ])
    }

    func testUnrelatedKeyGetsNoSuggestion() throws {
        let (_, warnings, file) = try load("something_else_entirely: true\n")

        XCTAssertEqual(warnings, ["\(file): invalid key 'something_else_entirely'"])
    }

    func testNonStringKeyIsReportedAsInvalid() throws {
        let (_, warnings, file) = try load("1: true\n")

        XCTAssertEqual(warnings, ["\(file): invalid key '1'"])
    }

    func testWarningsAreSortedByKey() throws {
        let (_, warnings, file) = try load("""
        strict: 1
        format: jsno
        bogus: 1
        """)

        XCTAssertEqual(warnings.count, 3)
        for (warning, prefix) in zip(warnings, ["invalid key 'bogus'", "'format'", "'strict'"]) {
            XCTAssertTrue(warning.hasPrefix("\(file): \(prefix)"), warning)
        }
    }

    // MARK: - Round trip

    func testSavedConfigurationLoadsBackWithoutWarning() throws {
        let configuration = Configuration()
        configuration.strict = true
        configuration.retainPublic = true
        configuration.outputFormat = .githubMarkdown
        configuration.color = .never
        configuration.cacheMaxAgeDays = 3
        configuration.schemes = ["App", "Tools"]
        configuration.project = FilePath("App.xcodeproj")
        configuration.indexStorePath = [FilePath("a"), FilePath("b")]
        configuration.reportExclude = [.pattern("**/Generated/*"), .scoped(path: "**/Kit/**", kinds: ["unused.function"])]
        configuration.superfluousIgnoreComments = false

        let file = FilePath(directory.appendingPathComponent("saved.yml").path)
        try configuration.save(to: file)

        let reloaded = Configuration()
        var warnings: [String] = []
        try reloaded.load(from: file) { warnings.append($0) }

        XCTAssertEqual(warnings, [])
        XCTAssertEqual(try reloaded.asYaml(), try configuration.asYaml())
        XCTAssertEqual(reloaded.reportExclude, configuration.reportExclude)
        XCTAssertEqual(reloaded.indexStorePath, configuration.indexStorePath)
        XCTAssertEqual(reloaded.outputFormat, .githubMarkdown)
    }

    // MARK: - Private

    private func onlyWarning(_ warnings: [String]) throws -> String {
        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        return try XCTUnwrap(warnings.first)
    }

    private func write(_ yaml: String) throws -> FilePath {
        let file = directory.appendingPathComponent(".periphery.yml")
        try yaml.write(to: file, atomically: true, encoding: .utf8)
        return FilePath(file.path)
    }

    private func load(_ yaml: String) throws -> (Configuration, [String], String) {
        let file = try write(yaml)
        let configuration = Configuration()
        var warnings: [String] = []
        try configuration.load(from: file) { warnings.append($0) }
        return (configuration, warnings, file.string)
    }
}
