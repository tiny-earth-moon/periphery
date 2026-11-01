import Foundation
import XCTest

final class NoThirdPartyEndpointsTest: XCTestCase {
    // TODO: add "api.github.com/repos/peripheryapp" once #139 is merged.
    private static let forbiddenEndpoints = ["periphery.pro"]

    func testNoThirdPartyEndpoints() throws {
        let sourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PeripheryTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("Sources")

        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: nil))
        var scanned = 0
        var offenders: [String] = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let contents = try String(contentsOf: url, encoding: .utf8)
            scanned += 1

            for endpoint in Self.forbiddenEndpoints where contents.contains(endpoint) {
                offenders.append("\(url.path) contains \(endpoint)")
            }
        }

        XCTAssertGreaterThan(scanned, 0, "No source files found under \(sourcesURL.path)")
        XCTAssertTrue(offenders.isEmpty, "Third-party endpoints found:\n" + offenders.joined(separator: "\n"))
    }
}
