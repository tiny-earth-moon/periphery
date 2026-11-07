enum FixtureWithoutOptionState {
    case idle
    case onlyMatched
}

public func fixtureWithoutOptionMatch() -> Bool {
    if case .onlyMatched = FixtureWithoutOptionState.idle { return true }
    return false
}
