protocol FixtureProtocol223Constrained {}
protocol FixtureProtocol223Constraint {}

extension FixtureProtocol223Constrained where Self: FixtureProtocol223Constraint {
    func unusedConstrainedMember() {}
}

struct FixtureStruct223Constrained: FixtureProtocol223Constrained {}

func fixture223ConstrainedApply(_: some FixtureProtocol223Constrained) {}

public func fixture223ConstrainedRetainer() {
    fixture223ConstrainedApply(FixtureStruct223Constrained())
}
