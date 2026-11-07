import Foundation

@objc protocol FixtureProtocol218 {
    func requirementCalledByRuntime()
}

class FixtureClass218: NSObject, FixtureProtocol218 {
    func requirementCalledByRuntime() {}
    func unrelatedMethod() {}
}

public func fixtureClass218Root() {
    _ = FixtureClass218()
}
