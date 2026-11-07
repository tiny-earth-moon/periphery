enum FixtureMatchedState {
    case constructed
    case matchedInSwitch
    case matchedQualified
    case matchedWithPayload(Int)
    case matchedWithBinding(String)
    case matchedInIfCase
    case matchedInGuardCase
    case matchedInWhileCase
    case matchedInForCase
    case matchedOptional
    case matchedInTuple
    case matchedNested
}

enum FixtureMatchedWrapper {
    case wrapped(FixtureMatchedState)
}

enum FixtureMatchedError: Error {
    case thrown
    case onlyCaught
}

public struct FixtureMatchedUser {
    public func matchSwitch() -> Int {
        let state = FixtureMatchedState.constructed
        switch state {
        case .matchedInSwitch: return 1
        case FixtureMatchedState.matchedQualified: return 2
        case let .matchedWithPayload(value): return value
        case .matchedWithBinding(let text): return text.count
        default: return 0
        }
    }

    public func matchConditions() -> Int {
        let state = FixtureMatchedState.constructed
        if case .matchedInIfCase = state { return 1 }
        guard case .matchedInGuardCase = state else { return 2 }
        var current = state
        while case .matchedInWhileCase = current {
            current = .constructed
        }
        for case .matchedInForCase in [state] {
            return 3
        }
        return 4
    }

    public func matchOptional() -> Bool {
        let state: FixtureMatchedState? = .constructed
        if case .matchedOptional? = state { return true }
        return false
    }

    public func matchTuple() -> Bool {
        switch (FixtureMatchedState.constructed, FixtureMatchedState.constructed) {
        case (.matchedInTuple, _): return true
        default: return false
        }
    }

    public func matchNested() -> Bool {
        let wrapper = FixtureMatchedWrapper.wrapped(.constructed)
        if case .wrapped(.matchedNested) = wrapper { return true }
        return false
    }

    public func matchCatch() -> Int {
        do {
            throw FixtureMatchedError.thrown
        } catch FixtureMatchedError.onlyCaught {
            return 1
        } catch {
            return 2
        }
    }
}
