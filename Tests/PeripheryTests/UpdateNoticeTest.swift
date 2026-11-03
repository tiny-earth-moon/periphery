import Shared
import XCTest

final class UpdateNoticeTest: XCTestCase {
    func testLatestReleaseURL_pointsToForkRepository() {
        XCTAssertEqual(
            UpdateNotice.latestReleaseURL.absoluteString,
            "https://api.github.com/repos/tiny-earth-moon/outskirts/releases/latest"
        )
    }

    func testNotification_linksToForkAndHasNoSponsorText() {
        let lines = UpdateNotice.lines(latestVersion: "9.9.9", localVersion: "1.0.0") { text, _ in text }
        let text = lines.joined(separator: "\n")

        XCTAssertTrue(text.contains("https://github.com/tiny-earth-moon/outskirts/releases/tag/9.9.9"), text)
        XCTAssertFalse(text.lowercased().contains("sponsor"), text)
        XCTAssertFalse(text.contains("peripheryapp"), text)
    }
}
