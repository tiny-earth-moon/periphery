public struct FixtureTypesStruct7 {
    static func typesBoth() {}
    func typesBoth(value: Int) {}
}

public struct FixtureTypesDistractor7 {
    func typesBoth() {}
}

public class FixtureTypesUser7 {
    public func entry() {
        #if os(macOS)
        FixtureTypesStruct7.typesBoth()
        #else
        FixtureTypesStruct7().typesBoth(value: 1)
        #endif
    }
}
