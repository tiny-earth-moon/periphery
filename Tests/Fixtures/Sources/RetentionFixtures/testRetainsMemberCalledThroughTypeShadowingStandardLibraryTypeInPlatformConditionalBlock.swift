public struct CollectionOfOne {
    init() {}
    func modulesResultLocal() {}
    func modulesResultSwift() {}
}

extension Swift.CollectionOfOne {
    func modulesResultSwift() {}
}

public struct FixtureModulesResultDecoy {
    func modulesResultLocal() {}
}

public struct FixtureModulesResultEntry {
    public func entry() {
        #if os(iOS)
        CollectionOfOne().modulesResultLocal()
        Swift.CollectionOfOne(1).modulesResultSwift()
        #endif
    }
}
