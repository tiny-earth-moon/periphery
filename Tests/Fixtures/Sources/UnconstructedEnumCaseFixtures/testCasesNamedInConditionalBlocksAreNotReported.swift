enum FixtureConditionalState {
    case idle
    case constructedInInactiveClause
    case matchedOnly
}

public func fixtureConditionalMatch() -> Int {
    #if FIXTURE_NEVER_DEFINED
        let state = FixtureConditionalState.constructedInInactiveClause
    #else
        let state = FixtureConditionalState.idle
    #endif
    if case .constructedInInactiveClause = state { return 1 }
    if case .matchedOnly = state { return 2 }
    return 0
}
