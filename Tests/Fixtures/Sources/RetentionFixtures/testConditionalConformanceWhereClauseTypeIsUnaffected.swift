protocol FixtureProtocol223Conditional {
    func conditionalRequirement()
}

struct FixtureStruct223ConditionalElement {}

extension Array: FixtureProtocol223Conditional where Element == FixtureStruct223ConditionalElement {
    func conditionalRequirement() {}
}

func fixture223ConditionalApply(_ value: some FixtureProtocol223Conditional) {
    value.conditionalRequirement()
}

public func fixture223ConditionalRetainer() {
    fixture223ConditionalApply([])
}
