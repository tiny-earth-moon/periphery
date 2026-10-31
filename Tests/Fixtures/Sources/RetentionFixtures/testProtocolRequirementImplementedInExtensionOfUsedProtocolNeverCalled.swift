import Foundation

protocol FixtureProtocol1102 {
    var requiredValue: Int { get }
    func requiredMethod()
}

struct FixtureStruct1102 {}

extension FixtureStruct1102: FixtureProtocol1102 {
    var requiredValue: Int { 1 }
    func requiredMethod() {}
}

public class FixtureClass1102Retainer {
    public func retain() {
        let a: FixtureProtocol1102 = FixtureStruct1102()
        _ = a
    }
}
