public struct FixtureTypesBox4<T> {}

extension FixtureTypesBox4 where T == Int {
    func typesConstrained() {}
}

public struct FixtureTypesDistractor4 {
    func typesConstrained() {}
}

public class FixtureTypesUser4 {
    public func entry() {
        #if os(iOS)
        FixtureTypesBox4<Int>().typesConstrained()
        #endif
    }
}
