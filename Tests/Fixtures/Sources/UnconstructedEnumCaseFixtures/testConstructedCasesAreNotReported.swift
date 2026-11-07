enum FixtureConstructedState: Equatable {
    case initial
    case assigned
    case returned
    case defaultArgument
    case inClosure
    case interpolated
    case inResultBuilder
    case inArray
    case passedAsArgument
    case ternary
    case comparedEqual
    case comparedNotEqual
    case functionValue(Int)
    case payloadArgument(Int)
    case matchedOnly
}

@resultBuilder
enum FixtureConstructedBuilder {
    static func buildBlock(_ states: FixtureConstructedState...) -> [FixtureConstructedState] {
        states
    }
}

public struct FixtureConstructedUser {
    public func assign() -> Bool {
        var state = FixtureConstructedState.initial
        state = .assigned
        return describe(state) && describe(returned()) && describe(state, fallback: .initial)
    }

    public func closures() -> Bool {
        let make: () -> FixtureConstructedState = { .inClosure }
        let text = "\(FixtureConstructedState.interpolated)"
        let built = build { FixtureConstructedState.inResultBuilder }
        let states: [FixtureConstructedState] = [.inArray]
        let picked: FixtureConstructedState = text.isEmpty ? .ternary : .initial
        let maker: (Int) -> FixtureConstructedState = FixtureConstructedState.functionValue
        return describe(make()) && built.isEmpty && states.isEmpty && describe(picked) && describe(maker(1))
            && describe(.passedAsArgument) && describe(.payloadArgument(1))
    }

    public func compare() -> Bool {
        let state = FixtureConstructedState.initial
        return state == .comparedEqual || state != .comparedNotEqual
    }

    private func returned() -> FixtureConstructedState {
        .returned
    }

    private func build(@FixtureConstructedBuilder _ content: () -> [FixtureConstructedState]) -> [FixtureConstructedState] {
        content()
    }

    private func describe(_ state: FixtureConstructedState, fallback: FixtureConstructedState = .defaultArgument) -> Bool {
        switch state {
        case .initial, .assigned, .returned, .defaultArgument, .inClosure, .interpolated, .inResultBuilder, .inArray,
             .passedAsArgument, .ternary, .comparedEqual, .comparedNotEqual, .functionValue, .payloadArgument, .matchedOnly:
            return fallback == .initial
        }
    }
}
