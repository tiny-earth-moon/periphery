import Configuration
@testable import Frontend
import Logger
import XCTest

final class ScanPreflightTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private func relativeResults(afterPreflightWith format: OutputFormat, relativeResults: Bool = false) -> Bool {
        let configuration = Configuration()
        configuration.outputFormat = format
        configuration.relativeResults = relativeResults
        ScanPreflight.applyOutputFormatRequirements(to: configuration, logger: logger)
        return configuration.relativeResults
    }

    func testOutputFormatRequirements_forceRelativeResultsForTheFormatsThatNeedThem() {
        for format in [OutputFormat.githubActions, .gitlabCodeQuality, .codeclimate] {
            XCTAssertTrue(relativeResults(afterPreflightWith: format), "\(format)")
        }
    }

    func testOutputFormatRequirements_leaveTheOtherFormatsAlone() {
        for format in [OutputFormat.xcode, .csv, .json, .checkstyle, .githubMarkdown] {
            XCTAssertFalse(relativeResults(afterPreflightWith: format), "\(format)")
        }
    }

    func testOutputFormatRequirements_keepAnExplicitRelativeResults() {
        XCTAssertTrue(relativeResults(afterPreflightWith: .xcode, relativeResults: true))
        XCTAssertTrue(relativeResults(afterPreflightWith: .githubActions, relativeResults: true))
    }
}
