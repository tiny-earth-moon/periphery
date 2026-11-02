public struct FixtureModulesGP {
    func modulesGPRun() {}
}

protocol FixtureModulesGPRunnable {
    init()
    func modulesGPRun()
}

public struct FixtureModulesGPImpl: FixtureModulesGPRunnable {
    init() {}
    func modulesGPRun() {}
}

public struct FixtureModulesGPEntry {
    func run<FixtureModulesGP: FixtureModulesGPRunnable>(_: FixtureModulesGP.Type) {
        #if os(iOS)
        FixtureModulesGP().modulesGPRun()
        #endif
    }

    public func entry() {
        run(FixtureModulesGPImpl.self)
    }
}
