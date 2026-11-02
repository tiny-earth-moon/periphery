public protocol FixtureModulesProvider {
    associatedtype FixtureModulesItem
    func modulesProvide() -> FixtureModulesItem
}

public struct FixtureModulesExternalBox<FixtureModulesSlot> {
    public init() {}
}

open class FixtureModulesExternalBase {
    public init() {}
}
