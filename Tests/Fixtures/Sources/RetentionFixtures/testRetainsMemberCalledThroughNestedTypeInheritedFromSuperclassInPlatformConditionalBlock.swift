public struct FixtureTypesItem14 {}

public class FixtureTypesBase14 {
    public struct FixtureTypesItem14 {
        func typesInheritedNested() {}
    }
}

public class FixtureTypesSub14: FixtureTypesBase14 {
    public func entry() {
        #if os(iOS)
        FixtureTypesItem14().typesInheritedNested()
        #endif
    }
}

public struct FixtureTypesDistractor14 {
    func typesInheritedNested() {}
}
