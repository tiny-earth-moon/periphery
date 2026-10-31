public protocol FixtureProtocol1120 {
    func calledRequirement()
}

public func fixture1120Call(_ value: FixtureProtocol1120) {
    value.calledRequirement()
}
