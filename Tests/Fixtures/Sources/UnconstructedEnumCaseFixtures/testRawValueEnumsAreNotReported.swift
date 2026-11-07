enum FixtureStringState: String {
    case idle
    case onlyMatched
}

enum FixtureIntState: Int {
    case idle
    case onlyMatched
}

public func fixtureRawValueMatch() -> Bool {
    if case .onlyMatched = FixtureStringState.idle { return true }
    if case .onlyMatched = FixtureIntState.idle { return true }
    return false
}
