import Foundation

protocol FixtureProtocol1103 {
    func withDefault()
    func withoutDefault()
}

extension FixtureProtocol1103 {
    func withDefault() {}
}

struct FixtureStruct1103 {}

extension FixtureStruct1103: FixtureProtocol1103 {
    func withDefault() {}
    func withoutDefault() {}
}

public class FixtureClass1103Retainer {
    public func retain() {
        let a: FixtureProtocol1103 = FixtureStruct1103()
        _ = a
    }
}
