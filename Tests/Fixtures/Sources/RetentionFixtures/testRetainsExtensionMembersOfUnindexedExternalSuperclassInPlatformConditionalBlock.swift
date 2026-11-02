import ExternalModuleFixtures

protocol FixtureModulesExternalRetroProto {}

extension FixtureModulesExternalRetroProto {
    func modulesExternalRetroRun() {}
}

extension FixtureModulesExternalBase: FixtureModulesExternalRetroProto {
    func modulesExternalExtRun() {}
}

public class FixtureModulesExternalSub: FixtureModulesExternalBase {}

public struct FixtureModulesExternalDecoy {
    func modulesExternalRetroRun() {}
    func modulesExternalExtRun() {}
}

public class FixtureModulesExternalEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesExternalSub().modulesExternalRetroRun()
        FixtureModulesExternalSub().modulesExternalExtRun()
        #endif
    }
}
