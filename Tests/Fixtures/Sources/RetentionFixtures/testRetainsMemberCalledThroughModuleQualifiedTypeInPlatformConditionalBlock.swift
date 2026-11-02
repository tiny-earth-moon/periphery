public struct FixtureModulesQualified {
    init() {}
    func modulesQualifiedRun() {}
    func modulesQualifiedAnnotatedRun() {}
}

public struct FixtureModulesQualifiedDecoy {
    func modulesQualifiedRun() {}
    func modulesQualifiedAnnotatedRun() {}
}

public struct FixtureModulesQualifiedEntry {
    public func entry() {
        #if os(iOS)
        RetentionFixtures.FixtureModulesQualified().modulesQualifiedRun()
        let value: RetentionFixtures.FixtureModulesQualified = .init()
        value.modulesQualifiedAnnotatedRun()
        #endif
    }
}
