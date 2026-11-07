protocol FixtureMatchable {
    var code: Int { get }
}

enum FixtureGenericOperatorState: FixtureMatchable {
    case idle
    case viaOperator

    var code: Int {
        switch self {
        case .idle: 0
        case .viaOperator: 1
        }
    }
}

func ~= <T: FixtureMatchable>(pattern: T, value: Int) -> Bool {
    pattern.code == value
}

public func fixtureGenericOperatorMatch(_ value: Int) -> Bool {
    FixtureGenericOperatorState.idle ~= value
}
