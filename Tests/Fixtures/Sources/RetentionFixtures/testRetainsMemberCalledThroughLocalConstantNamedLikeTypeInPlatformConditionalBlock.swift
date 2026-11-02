public struct FixtureModulesLocal {
    func modulesLocalRun() {}
}

public struct FixtureModulesLocalReal {
    func modulesLocalRun() {}
}

public struct FixtureModulesLocalEntry {
    public func entry() {
        let FixtureModulesLocal = FixtureModulesLocalReal()
        #if os(iOS)
        FixtureModulesLocal.modulesLocalRun()
        #endif
        _ = FixtureModulesLocal
    }
}
