extension Hashable {
    func typesHashable() -> Int { hashValue }
}

public enum FixtureTypesEnum8 {
    case first
    case second
}

public struct FixtureTypesDistractor8 {
    func typesHashable() -> Int { 0 }
}

public class FixtureTypesUser8 {
    public func entry() {
        #if os(iOS)
        let value: FixtureTypesEnum8 = .first
        _ = value.typesHashable()
        #endif
    }
}
