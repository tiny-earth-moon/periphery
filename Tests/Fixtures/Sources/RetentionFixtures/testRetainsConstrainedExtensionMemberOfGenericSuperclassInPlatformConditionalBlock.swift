public class FixtureTypesBase13<T> {}

extension FixtureTypesBase13 where T == Int {
    func typesGenSuper() {}
}

public class FixtureTypesSub13: FixtureTypesBase13<Int> {}

public struct FixtureTypesDistractor13 {
    func typesGenSuper() {}
}

public class FixtureTypesUser13 {
    public func entry() {
        #if targetEnvironment(simulator)
        FixtureTypesSub13().typesGenSuper()
        #endif
    }
}
