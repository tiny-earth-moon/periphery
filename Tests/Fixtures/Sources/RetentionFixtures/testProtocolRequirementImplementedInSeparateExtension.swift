import Foundation

protocol FixtureProtocol1101 {
    func calledRequirement()
    func uncalledRequirement()
}

struct FixtureStruct1101 {}

extension FixtureStruct1101: FixtureProtocol1101 {}

extension FixtureStruct1101 {
    func calledRequirement() {}
    func uncalledRequirement() {}
}

public class FixtureClass1101Retainer {
    public func retain() {
        let a: FixtureProtocol1101 = FixtureStruct1101()
        a.calledRequirement()
    }
}
