import Foundation

protocol FixtureProtocol1104 {
    func requiredMethod()
}

class FixtureClass1104Base {}

extension FixtureClass1104Base {
    func requiredMethod() {}
}

class FixtureClass1104: FixtureClass1104Base, FixtureProtocol1104 {}

public class FixtureClass1104Retainer {
    public func retain() {
        let a: FixtureProtocol1104 = FixtureClass1104()
        _ = a
    }
}
