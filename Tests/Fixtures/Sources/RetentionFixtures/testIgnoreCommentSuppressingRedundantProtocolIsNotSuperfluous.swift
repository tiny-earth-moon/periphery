// periphery:ignore
protocol FixtureIgnoredRedundantProtocol {}

// periphery:ignore
protocol FixtureIgnoredRedundantProtocolWithMember {
    func ignoredRequirement()
}

protocol FixtureNotIgnoredRedundantProtocol {}

// periphery:ignore
protocol FixtureIgnoredExistentialProtocol {}

class FixtureIgnoredRedundantProtocolConformer: FixtureIgnoredRedundantProtocol, FixtureIgnoredRedundantProtocolWithMember, FixtureNotIgnoredRedundantProtocol, FixtureIgnoredExistentialProtocol {
    func ignoredRequirement() {}
}

public func fixtureIgnoredRedundantProtocolRoot() {
    let existential: FixtureIgnoredExistentialProtocol = FixtureIgnoredRedundantProtocolConformer()
    print(existential)
}
