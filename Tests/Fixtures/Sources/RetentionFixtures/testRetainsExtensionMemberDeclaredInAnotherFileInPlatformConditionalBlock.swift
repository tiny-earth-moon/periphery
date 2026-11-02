public struct FixtureModulesSplit {
    public init() {}
}

public struct FixtureModulesSplitDecoy {
    func modulesSplitRun() {}
}

public struct FixtureModulesSplitEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesSplit().modulesSplitRun()
        #endif
    }
}
