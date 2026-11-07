struct FixtureOperatorToken {
    let name: String
}

enum FixtureOperatorInner {
    case idle
    case onlyInWrappedPattern
    case onlyInOptionalWrappedPattern
}

enum FixtureOperatorWrapper {
    case wrap(FixtureOperatorInner)
}

enum FixtureOptionalOperatorWrapper {
    case wrap(FixtureOperatorInner)
}

var fixtureLastMatchedWrapper: FixtureOperatorWrapper?

func ~= (pattern: FixtureOperatorWrapper, value: FixtureOperatorToken) -> Bool {
    fixtureLastMatchedWrapper = pattern
    return "\(pattern)".hasSuffix("\(value.name))")
}

func ~= (pattern: FixtureOptionalOperatorWrapper?, value: FixtureOperatorToken) -> Bool {
    pattern != nil && value.name.isEmpty
}

public func fixtureOperatorRoute(_ name: String) -> String {
    let token = FixtureOperatorToken(name: name)
    switch token {
    case .wrap(.onlyInWrappedPattern): return "matched"
    case .some(.wrap(.onlyInOptionalWrappedPattern)): return "optional"
    default: break
    }
    guard case let .wrap(inner)? = fixtureLastMatchedWrapper else { return "other" }
    switch inner {
    case .idle: return "idle"
    case .onlyInWrappedPattern: return "inner"
    case .onlyInOptionalWrappedPattern: return "optional inner"
    }
}

public func fixtureOperatorIdle() -> Bool {
    fixtureOperatorRoute("") == "" && FixtureOperatorWrapper.wrap(.idle) ~= FixtureOperatorToken(name: "")
        && FixtureOptionalOperatorWrapper.wrap(.idle) ~= FixtureOperatorToken(name: "")
}
