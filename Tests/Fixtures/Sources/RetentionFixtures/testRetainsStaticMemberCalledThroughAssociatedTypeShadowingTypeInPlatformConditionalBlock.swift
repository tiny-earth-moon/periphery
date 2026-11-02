protocol FixtureTypesNodeProtocol11 {
    static func typesAssoc()
}

struct FixtureTypesConformer11: FixtureTypesNodeProtocol11 {
    static func typesAssoc() {}
}

public struct FixtureTypesNode11 {}

protocol FixtureTypesP11 {
    associatedtype FixtureTypesNode11: FixtureTypesNodeProtocol11 = FixtureTypesConformer11
}

extension FixtureTypesP11 {
    func entry() {
        #if os(iOS)
        FixtureTypesNode11.typesAssoc()
        #endif
    }
}

struct FixtureTypesConforming11: FixtureTypesP11 {}

public class FixtureTypesUser11 {
    public func entry() {
        FixtureTypesConforming11().entry()
    }
}
