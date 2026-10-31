import Foundation

@objc protocol FixtureProtocol1114 {
    @objc optional func optionalRequirement()
    func requiredRequirement()
}

class FixtureClass1114: NSObject {}

extension FixtureClass1114: FixtureProtocol1114 {
    func optionalRequirement() {}
    func requiredRequirement() {}
}

public class FixtureClass1114Retainer {
    public func retain() {
        let a: FixtureProtocol1114 = FixtureClass1114()
        a.requiredRequirement()
        a.optionalRequirement?()
    }
}
