struct FixtureArrayLiteral: ExpressibleByArrayLiteral {
    init(arrayLiteral _: Int...) {}
}

struct FixtureDictionaryLiteral: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral _: (String, Int)...) {}
}

struct FixtureStringLiteral: ExpressibleByStringLiteral {
    init(stringLiteral _: String) {}
}

struct FixtureIntegerLiteral: ExpressibleByIntegerLiteral {
    init(integerLiteral _: Int) {}
}

struct FixtureFloatLiteral: ExpressibleByFloatLiteral {
    init(floatLiteral _: Double) {}
}

struct FixtureBooleanLiteral: ExpressibleByBooleanLiteral {
    init(booleanLiteral _: Bool) {}
}

struct FixtureNilLiteral: ExpressibleByNilLiteral {
    init(nilLiteral _: ()) {}
}

struct FixtureUnicodeScalarLiteral: ExpressibleByUnicodeScalarLiteral {
    typealias UnicodeScalarLiteralType = Unicode.Scalar

    init(unicodeScalarLiteral _: Unicode.Scalar) {}
}

struct FixtureExtendedGraphemeClusterLiteral: ExpressibleByExtendedGraphemeClusterLiteral {
    typealias ExtendedGraphemeClusterLiteralType = Character

    init(extendedGraphemeClusterLiteral _: Character) {}
}

public struct FixtureLiteralUser {
    public init() {}

    public func build() {
        let _: FixtureArrayLiteral = [1]
        let _: FixtureDictionaryLiteral = ["a": 1]
        let _: FixtureStringLiteral = "abc"
        let _: FixtureIntegerLiteral = 1
        let _: FixtureFloatLiteral = 1.5
        let _: FixtureBooleanLiteral = true
        let _: FixtureNilLiteral = nil
        let _: FixtureUnicodeScalarLiteral = "a"
        let _: FixtureExtendedGraphemeClusterLiteral = "e\u{301}"
    }
}
