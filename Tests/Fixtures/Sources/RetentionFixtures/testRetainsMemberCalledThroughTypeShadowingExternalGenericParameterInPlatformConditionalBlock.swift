import ExternalModuleFixtures

public struct FixtureModulesSlot {
    func modulesSlotRun() {}
}

public struct FixtureModulesRealSlot {
    init() {}
    func modulesSlotRun() {}
}

extension FixtureModulesExternalBox where FixtureModulesSlot == FixtureModulesRealSlot {
    public func entry() {
        #if os(iOS)
        FixtureModulesSlot().modulesSlotRun()
        #endif
    }
}
