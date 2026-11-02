import ExternalModuleFixtures

public struct FixtureModulesItem {
    func modulesItemRun() {}
}

public struct FixtureModulesRealItem {
    init() {}
    func modulesItemRun() {}
}

public struct FixtureModulesItemProvider: FixtureModulesProvider {
    public func modulesProvide() -> FixtureModulesRealItem { FixtureModulesRealItem() }

    public func entry() {
        #if os(iOS)
        FixtureModulesItem().modulesItemRun()
        #endif
    }
}
