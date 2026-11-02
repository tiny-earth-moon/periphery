public enum FixtureTypesEnum6 {
    case typesCase(Int)
    case other

    static func typesStatic() {}
}

public struct FixtureTypesDistractor6 {
    func typesCase() {}
    func typesStatic() {}
}

public class FixtureTypesUser6 {
    public func entry() {
        #if os(iOS)
        _ = FixtureTypesEnum6.typesCase(1)
        FixtureTypesEnum6.typesStatic()
        #endif
    }
}
