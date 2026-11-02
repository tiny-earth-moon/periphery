import Foundation

protocol FixtureModulesStylable {
    func modulesApplyStyle()
}

extension NSObject: FixtureModulesStylable {
    func modulesApplyStyle() {}
}

public class FixtureModulesStyledView: NSObject {}

public struct FixtureModulesStyleDecoy {
    func modulesApplyStyle() {}
}

public class FixtureModulesStyleEntry {
    public func entry() {
        #if os(iOS)
        FixtureModulesStyledView().modulesApplyStyle()
        #endif
    }
}
