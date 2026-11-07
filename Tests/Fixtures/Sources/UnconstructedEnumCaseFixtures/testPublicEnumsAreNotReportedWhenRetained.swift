public enum FixturePublicState {
    case idle
    case onlyMatched
}

enum FixtureInternalState {
    case idle
    case onlyMatched
}

public func fixturePublicMatch(_ state: FixturePublicState) -> Bool {
    if case .onlyMatched = FixtureInternalState.idle { return true }
    if case .onlyMatched = state { return true }
    return false
}
