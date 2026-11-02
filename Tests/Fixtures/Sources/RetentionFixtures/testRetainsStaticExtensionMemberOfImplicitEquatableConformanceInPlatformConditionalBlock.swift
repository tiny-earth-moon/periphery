extension Equatable {
    static func typesEquatableStatic() {}
}

public enum FixtureTypesEnum16 {
    case first
}

public struct FixtureTypesDistractor16 {
    static func typesEquatableStatic() {}
}

public class FixtureTypesUser16 {
    public func entry() {
        #if os(macOS)
        #else
        FixtureTypesEnum16.typesEquatableStatic()
        #endif
    }
}
