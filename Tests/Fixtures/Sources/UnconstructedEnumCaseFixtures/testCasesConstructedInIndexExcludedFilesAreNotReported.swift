enum FixtureExcludedState {
    case idle
    case constructedInExcludedFile
    case matchedOnly
}

public func fixtureExcludedMatch() -> Int {
    let state = FixtureExcludedState.idle
    if case .constructedInExcludedFile = state { return 1 }
    if case .matchedOnly = state { return 2 }
    return 0
}
