@testable import SourceGraph
import XCTest

final class LocalizedStringKeyMatcherTest: XCTestCase {
    func testMatchesExactKeys() {
        let matcher = LocalizedStringKeyMatcher(usedKeys: ["title"])

        XCTAssertTrue(matcher.matches("title"))
        XCTAssertFalse(matcher.matches("subtitle"))
    }

    func testMatchesStringInterpolationWithAnySpecifier() {
        let matcher = LocalizedStringKeyMatcher(usedKeys: ["Hello %@"])

        XCTAssertTrue(matcher.matches("Hello %@"))
        XCTAssertTrue(matcher.matches("Hello %lld"))
        XCTAssertFalse(matcher.matches("Hello"))
        XCTAssertFalse(matcher.matches("Hello %@ %@"))
    }

    func testMatchesIntegerInterpolation() {
        let matcher = LocalizedStringKeyMatcher(usedKeys: ["hud.ammo.value %@"])

        XCTAssertTrue(matcher.matches("hud.ammo.value %lld"))
        XCTAssertTrue(matcher.matches("hud.ammo.value %1$lld"))
        XCTAssertFalse(matcher.matches("hud.ammo.empty"))
    }

    func testMatchesDoubleInterpolation() {
        let matcher = LocalizedStringKeyMatcher(usedKeys: ["%@ km away"])

        XCTAssertTrue(matcher.matches("%lf km away"))
        XCTAssertTrue(matcher.matches("%.2f km away"))
        XCTAssertFalse(matcher.matches("%lf miles away"))
    }

    func testKeepsEscapedPercentLiteral() {
        let matcher = LocalizedStringKeyMatcher(usedKeys: ["%@%% done"])

        XCTAssertTrue(matcher.matches("%lld%% done"))
        XCTAssertFalse(matcher.matches("%lld%@ done"))
    }

    func testFormatSkeleton() {
        XCTAssertNil(LocalizedStringKeyMatcher.formatSkeleton(of: "plain"))
        XCTAssertNil(LocalizedStringKeyMatcher.formatSkeleton(of: "100%% sure"))
        XCTAssertEqual(
            LocalizedStringKeyMatcher.formatSkeleton(of: "%1$@ has %2$lld points"),
            LocalizedStringKeyMatcher.formatSkeleton(of: "%@ has %@ points")
        )
    }
}
