protocol FixtureTypesP10 {
    static func typesGeneric()
}

struct FixtureTypesConformer10: FixtureTypesP10 {
    static func typesGeneric() {}
}

public struct FixtureTypesItem10 {}

struct FixtureTypesWrapper10<FixtureTypesItem10: FixtureTypesP10> {
    public func entry() {
        #if os(iOS)
        FixtureTypesItem10.typesGeneric()
        #endif
    }
}

public class FixtureTypesUser10 {
    public func entry() {
        FixtureTypesWrapper10<FixtureTypesConformer10>().entry()
    }
}
