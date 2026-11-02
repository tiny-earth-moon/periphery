public struct FixtureModulesTopAliasTarget {
    init() {}
    func modulesTopAliasRun() {}
    func modulesTopAliasAnnotatedRun() {}
}

typealias FixtureModulesTopAlias = FixtureModulesTopAliasTarget

public struct FixtureModulesTopAliasDecoy {
    func modulesTopAliasRun() {}
    func modulesTopAliasAnnotatedRun() {}
}

public struct FixtureModulesTopAliasEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesTopAlias().modulesTopAliasRun()
        let value: FixtureModulesTopAlias = .init()
        value.modulesTopAliasAnnotatedRun()
        #endif
    }
}
