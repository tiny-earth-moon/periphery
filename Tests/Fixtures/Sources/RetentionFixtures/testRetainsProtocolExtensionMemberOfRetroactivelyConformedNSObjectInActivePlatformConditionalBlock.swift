import Foundation

protocol FixtureModulesThemeableActive {}

extension FixtureModulesThemeableActive {
    func modulesApplyThemeActive() {}
}

extension NSObject: FixtureModulesThemeableActive {}

public class FixtureModulesViewActive: NSObject {}

public struct FixtureModulesThemeDecoyActive {
    func modulesApplyThemeActive() {}
}

public class FixtureModulesThemeEntryActive {
    public func entry() {
        #if os(macOS)
        FixtureModulesViewActive().modulesApplyThemeActive()
        #endif
    }
}
