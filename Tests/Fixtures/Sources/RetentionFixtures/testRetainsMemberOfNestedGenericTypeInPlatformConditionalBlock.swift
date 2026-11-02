public struct FixtureTypesOuter5<T> {
    public struct Inner<U> {
        func typesNested() {}
    }
}

public struct FixtureTypesDistractor5 {
    func typesNested() {}
}

public class FixtureTypesUser5 {
    public func entry() {
        #if os(iOS)
        FixtureTypesOuter5<Int>.Inner<String>().typesNested()
        #endif
    }
}
