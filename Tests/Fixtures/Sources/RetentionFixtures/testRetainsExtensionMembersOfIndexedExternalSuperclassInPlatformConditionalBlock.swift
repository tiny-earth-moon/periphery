import ExternalModuleFixtures

protocol FixtureModulesIndexedRetroProto {}

extension FixtureModulesIndexedRetroProto {
    func modulesIndexedRetroRun() {}
}

extension FixtureModulesIndexedBase: FixtureModulesIndexedRetroProto {}

extension FixtureModulesIndexedBase {
    func modulesIndexedExtRun() {}
}

public class FixtureModulesIndexedSub: FixtureModulesIndexedBase {}

public struct FixtureModulesIndexedDecoy {
    func modulesIndexedRetroRun() {}
    func modulesIndexedExtRun() {}
}

public class FixtureModulesIndexedEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesIndexedSub().modulesIndexedRetroRun()
        FixtureModulesIndexedSub().modulesIndexedExtRun()
        #endif
    }
}
