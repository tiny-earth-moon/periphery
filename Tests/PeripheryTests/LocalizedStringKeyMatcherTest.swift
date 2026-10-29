@testable import SourceGraph
import XCTest

final class LocalizedStringKeyMatcherTest: XCTestCase {
    func testMatchesExactKeys() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: ["title"])

        XCTAssertTrue(matcher.matches("title"))
        XCTAssertFalse(matcher.matches("subtitle"))
    }

    func testMatchesStringInterpolationWithAnySpecifier() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: ["Hello %@"])

        XCTAssertTrue(matcher.matches("Hello %@"))
        XCTAssertTrue(matcher.matches("Hello %lld"))
        XCTAssertFalse(matcher.matches("Hello"))
        XCTAssertFalse(matcher.matches("Hello %@ %@"))
    }

    func testMatchesIntegerInterpolation() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: ["hud.ammo.value %@"])

        XCTAssertTrue(matcher.matches("hud.ammo.value %lld"))
        XCTAssertTrue(matcher.matches("hud.ammo.value %1$lld"))
        XCTAssertFalse(matcher.matches("hud.ammo.empty"))
    }

    func testMatchesDoubleInterpolation() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: ["%@ km away"])

        XCTAssertTrue(matcher.matches("%lf km away"))
        XCTAssertTrue(matcher.matches("%.2f km away"))
        XCTAssertFalse(matcher.matches("%lf miles away"))
    }

    func testKeepsEscapedPercentLiteral() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: ["%@%% done"])

        XCTAssertTrue(matcher.matches("%lld%% done"))
        XCTAssertFalse(matcher.matches("%lld%@ done"))
    }

    func testMatchesGlobPatterns() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: [], patterns: ["quickChat.*", "pose.?.label"])

        XCTAssertTrue(matcher.matches("quickChat.hello"))
        XCTAssertTrue(matcher.matches("quickChat."))
        XCTAssertTrue(matcher.matches("pose.a.label"))
        XCTAssertFalse(matcher.matches("pose.ab.label"))
        XCTAssertFalse(matcher.matches("menu.quickChat.hello"))
        XCTAssertFalse(matcher.matches("quickChatTitle"))
    }

    func testMatchesRegularExpressionPatterns() throws {
        let matcher = try LocalizedStringKeyMatcher(usedKeys: [], patterns: ["/tier\\.(gold|silver)\\.label/"])

        XCTAssertTrue(matcher.matches("tier.gold.label"))
        XCTAssertFalse(matcher.matches("tier.bronze.label"))
        XCTAssertFalse(matcher.matches("tier.gold.label.hint"))
    }

    func testRejectsInvalidRegularExpressionPattern() {
        XCTAssertThrowsError(try LocalizedStringKeyMatcher(usedKeys: [], patterns: ["/tier.(/"]))
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
