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
        let expected: Set<OutputFormat> = [.githubActions, .gitlabCodeQuality, .codeclimate]

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
}
