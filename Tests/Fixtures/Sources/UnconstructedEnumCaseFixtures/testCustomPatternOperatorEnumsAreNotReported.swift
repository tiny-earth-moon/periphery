enum FixturePatternOperatorState {
    case idle
    case viaOperator
}

func ~= (pattern: FixturePatternOperatorState, value: Int) -> Bool {
    switch pattern {
    case .idle: value == 0
    case .viaOperator: value == 1
    }
}

public func fixturePatternOperatorMatch(_ value: Int) -> Bool {
    switch value {
    case .viaOperator: true
    default: false
    }
}

public func fixturePatternOperatorIdle() -> Bool {
    fixturePatternOperatorMatch(0) && FixturePatternOperatorState.idle ~= 0
}
