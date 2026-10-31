import Foundation

protocol FixtureProtocol1100 {
    func calledRequirement()
    func uncalledRequirement()
}

class FixtureClass1100 {}

extension FixtureClass1100: FixtureProtocol1100 {
    func calledRequirement() {}
    func uncalledRequirement() {}
}

public class FixtureClass1100Retainer {
    public func retain() {
        let a: FixtureProtocol1100 = FixtureClass1100()
        a.calledRequirement()
    }
}
