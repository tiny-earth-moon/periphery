import ExternalModuleFixtures

public struct FixtureModulesShared {
    init() {}
    func modulesSharedRun() {}
    func modulesSharedAnnotatedRun() {}
}

public struct FixtureModulesSharedEntry {
    public func entry() {
        #if os(iOS)
        ExternalModuleFixtures.FixtureModulesShared().modulesSharedRun()
        let value: ExternalModuleFixtures.FixtureModulesShared = .init()
        value.modulesSharedAnnotatedRun()
        #endif
    }
}
