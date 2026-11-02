public struct FixtureModulesAliasTarget {
    init() {}
    func modulesAliasRun() {}
    func modulesAliasAnnotatedRun() {}
}

public struct FixtureModulesAliasDecoy {
    func modulesAliasRun() {}
    func modulesAliasAnnotatedRun() {}
}

public struct FixtureModulesAliasHolder {
    typealias Target = FixtureModulesAliasTarget

    public func entry() {
        #if os(iOS)
        FixtureModulesAliasHolder.Target().modulesAliasRun()
        let value: FixtureModulesAliasHolder.Target = .init()
        value.modulesAliasAnnotatedRun()
        #endif
    }
}
