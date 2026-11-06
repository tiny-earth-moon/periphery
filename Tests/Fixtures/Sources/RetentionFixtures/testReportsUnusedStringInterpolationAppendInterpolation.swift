import Foundation

extension String.StringInterpolation {
    mutating func appendInterpolation(fixtureUsedHex value: Int) {
        appendLiteral(String(value, radix: 16))
    }

    mutating func appendInterpolation(fixtureDeadOctal value: Int) {
        appendLiteral(String(value, radix: 8))
    }
}

public struct Fixture112b {
    public func someFunc() {
        print("hex: \(fixtureUsedHex: 255)")
    }
}
