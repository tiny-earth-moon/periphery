import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class RelativeResultPathsTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)
    private let projectRoot = FilePath("/work/project")
    private let absolutePath = "/work/project/Sources/Lib/Tagged.swift"
    private let relativePath = "Sources/Lib/Tagged.swift"

    private func result() -> ScanResult {
        let file = SourceFile(path: FilePath(absolutePath), modules: ["Lib"])
        let declaration = Declaration(name: "Tagged", kind: .class, usrs: ["s:3Lib6TaggedC"], location: Location(file: file, line: 2, column: 20))
        return ScanResult(declaration: declaration, annotation: .unused)
    }

    private func jsonLocationPath(of output: String?) throws -> String {
        let data = try XCTUnwrap(output?.data(using: .utf8))
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let location = try XCTUnwrap(objects.first?["location"] as? [String: Any])
        return try XCTUnwrap(location["path"] as? String)
    }

    // MARK: - Formats that require relative paths

    func testRequiresRelativePaths_isLimitedToTheFormatsThatNeedIt() {
        let expected: Set<OutputFormat> = [.githubActions, .gitlabCodeQuality, .codeclimate, .sarif, .agent]

        for format in OutputFormat.allCases {
            XCTAssertEqual(format.requiresRelativePaths, expected.contains(format), "\(format)")
        }
    }

    func testGitHubActions_withTheDefaultConfiguration_emitsARelativePath() throws {
        let formatter = GitHubActionsFormatter(configuration: Configuration(), logger: logger)
        formatter.currentFilePath = projectRoot

        XCTAssertEqual(
            try formatter.format([result()], colored: false),
            "::warning file=\(relativePath),line=2,col=20,title=unused::Unused class 'Tagged'"
        )
    }

    func testGitHubActions_withoutResults_doesNotThrow() throws {
        let formatter = GitHubActionsFormatter(configuration: Configuration(), logger: logger)

        XCTAssertNil(try formatter.format([], colored: false))
    }

    func testGitLabCodeQuality_withTheDefaultConfiguration_emitsARelativePath() throws {
        let formatter = GitLabCodeQualityFormatter(configuration: Configuration(), logger: logger)
        formatter.currentFilePath = projectRoot

        XCTAssertEqual(try jsonLocationPath(of: formatter.format([result()], colored: false)), relativePath)
    }

    func testCodeClimate_withTheDefaultConfiguration_emitsARelativePath() throws {
        let formatter = CodeClimateFormatter(configuration: Configuration(), logger: logger)
        formatter.currentFilePath = projectRoot

        XCTAssertEqual(try jsonLocationPath(of: formatter.format([result()], colored: false)), relativePath)
    }

    // MARK: - Formats left unchanged

    func testFormatsWithoutTheRequirement_keepAbsolutePathsByDefault() throws {
        for format in [OutputFormat.xcode, .csv, .json, .checkstyle, .githubMarkdown] {
            let formatter = format.formatter.init(configuration: Configuration(), logger: logger)
            let output = try XCTUnwrap(formatter.format([result()], colored: false), "\(format)")

            XCTAssertTrue(output.contains(absolutePath), "\(format): \(output)")
        }
    }

    // MARK: - Relative results base

    private func configuration(base: String?) -> Configuration {
        let configuration = Configuration()
        configuration.relativeResults = true
        configuration.relativeResultsBase = base.map { FilePath($0) }
        return configuration
    }

    private func format(_ format: OutputFormat, base: String?) throws -> String {
        let formatter = format.formatter.init(configuration: configuration(base: base), logger: logger)
        formatter.currentFilePath = projectRoot
        return try XCTUnwrap(formatter.format([result()], colored: false), "\(format)")
    }

    func testEveryFormatter_withTheBaseSetToTheParentOfTheProjectRoot_emitsThePathFromThatBase() throws {
        for format in OutputFormat.allCases {
            let output = try self.format(format, base: "/work")
            // SARIF names the base once, as the absolute URI the relative paths are resolved from.
            let paths = format == .sarif ? output.replacingOccurrences(of: "\"uri\" : \"file:///work/\"", with: "") : output

            XCTAssertTrue(output.contains("project/\(relativePath)"), "\(format): \(output)")
            XCTAssertFalse(paths.contains("/work/"), "\(format): \(output)")
        }
    }

    func testEveryFormatter_withoutABase_emitsThePathFromTheProjectRoot() throws {
        for format in OutputFormat.allCases {
            let output = try self.format(format, base: nil)

            XCTAssertTrue(output.contains(relativePath), "\(format): \(output)")
            XCTAssertFalse(output.contains("project/\(relativePath)"), "\(format): \(output)")
        }
    }

    func testRelativeBase_isResolvedFromTheProjectRoot() throws {
        let output = try format(.codeclimate, base: "..")

        XCTAssertEqual(try jsonLocationPath(of: output), "project/\(relativePath)")
    }

    func testRelativeBase_withTheProjectRootAsBase_matchesTheDefault() throws {
        XCTAssertEqual(try format(.json, base: "/work/project"), try format(.json, base: nil))
    }

    func testBaseOutsideAnyResultPath_keepsParentComponents() throws {
        let output = try format(.codeclimate, base: "/work/other")

        XCTAssertEqual(try jsonLocationPath(of: output), "../project/\(relativePath)")
    }

    func testBaseIsIgnored_whenResultsAreNotRelative() throws {
        let configuration = Configuration()
        configuration.relativeResultsBase = FilePath("/work")
        let formatter = JsonFormatter(configuration: configuration, logger: logger)
        formatter.currentFilePath = projectRoot

        XCTAssertTrue(try XCTUnwrap(formatter.format([result()], colored: false)).contains(absolutePath))
    }
}
