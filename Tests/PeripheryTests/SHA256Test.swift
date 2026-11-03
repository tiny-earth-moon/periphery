import Foundation
@testable import PeripheryKit
import XCTest

final class SHA256Test: XCTestCase {
    func testEmptyInput() {
        XCTAssertEqual(
            SHA256.hexDigest(of: Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testShortInput() {
        XCTAssertEqual(
            SHA256.hexDigest(of: Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testInputSpanningTwoBlocks() {
        XCTAssertEqual(
            SHA256.hexDigest(of: Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
    }
}
