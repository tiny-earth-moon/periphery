protocol FixtureTypesP15 {
    func typesReq()
}

public class FixtureTypesBase15 {
    func typesReq() {}
}

public class FixtureTypesSub15: FixtureTypesBase15, FixtureTypesP15 {}

public struct FixtureTypesDistractor15 {
    func typesReq() {}
}

public class FixtureTypesUser15 {
    public func entry() {
        #if os(iOS)
        FixtureTypesSub15().typesReq()
        #endif
    }
}
