enum FixtureIterableState: CaseIterable {
    case idle
    case onlyMatched
}

public func fixtureIterableMatch() -> Bool {
    if case .onlyMatched = FixtureIterableState.idle { return true }
    return false
}
