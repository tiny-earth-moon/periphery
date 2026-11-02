import Foundation

protocol FixtureModulesThemeable {}

extension FixtureModulesThemeable {
    func modulesApplyTheme() {}
}

extension NSObject: FixtureModulesThemeable {}

public class FixtureModulesView: NSObject {}

public struct FixtureModulesThemeDecoy {
    func modulesApplyTheme() {}
}

public class FixtureModulesThemeEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesView().modulesApplyTheme()
        #endif
    }
}
