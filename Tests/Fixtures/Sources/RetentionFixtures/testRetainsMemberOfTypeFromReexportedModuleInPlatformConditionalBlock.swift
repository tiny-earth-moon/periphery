public struct FixtureModulesExportedDecoy {
    func modulesExportedRun() {}
}

public struct FixtureModulesExportedEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesExportedType().modulesExportedRun()
        #endif
    }
}
