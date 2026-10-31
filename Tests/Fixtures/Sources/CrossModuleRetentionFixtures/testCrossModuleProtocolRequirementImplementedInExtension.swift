import CrossModuleRetentionSupportFixtures

struct FixtureStruct1120 {}

extension FixtureStruct1120: FixtureProtocol1120 {
    func calledRequirement() {}
}

// periphery:ignore
class FixtureClass1120Retainer {
    func retain() {
        fixture1120Call(FixtureStruct1120())
    }
}
