protocol FixtureTypesP3 {}

extension FixtureTypesP3 {
    func typesCond() {}
}

public struct FixtureTypesBox3<T> {}

extension FixtureTypesBox3: FixtureTypesP3 where T == Int {}

public struct FixtureTypesDistractor3 {
    func typesCond() {}
}

public class FixtureTypesUser3 {
    public func entry() {
        #if os(iOS)
        FixtureTypesBox3<Int>().typesCond()
        #endif
    }
}
