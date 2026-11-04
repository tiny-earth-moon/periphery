extension String.StringInterpolation {
    mutating func appendInterpolation(fixtureLabel value: Int) {
        appendInterpolation(value)
    }
}

public struct FixtureInterpolationUser {
    public init() {}

    public func build() {
        print("value: \(fixtureLabel: 1)")
    }
}
