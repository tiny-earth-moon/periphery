import Foundation

protocol FixtureProtocol1112 {
    func conditionalRequirement() -> Int
}

struct FixtureStruct1112<T> {
    let value: T
}

extension FixtureStruct1112: FixtureProtocol1112 where T == Int {
    func conditionalRequirement() -> Int { value }
}

protocol FixtureProtocol1113Base {
    func baseRequirement()
}

protocol FixtureProtocol1113: FixtureProtocol1113Base {
    func derivedRequirement()
}

struct FixtureStruct1113 {}

extension FixtureStruct1113: FixtureProtocol1113 {
    func baseRequirement() {}
    func derivedRequirement() {}
}

public class FixtureClass1112Retainer {
    public func retain() {
        let a: FixtureProtocol1112 = FixtureStruct1112(value: 1)
        _ = a.conditionalRequirement()
        let b: FixtureProtocol1113 = FixtureStruct1113()
        b.baseRequirement()
        b.derivedRequirement()
    }
}
