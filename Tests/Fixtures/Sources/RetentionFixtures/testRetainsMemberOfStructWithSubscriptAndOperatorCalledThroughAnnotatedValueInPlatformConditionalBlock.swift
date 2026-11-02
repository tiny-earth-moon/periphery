public struct FixtureTypesStruct17 {
    subscript(index: Int) -> Int { index }

    static func + (lhs: Self, rhs: Self) -> Self { lhs }

    func typesCallAsFunction() {}
}

public struct FixtureTypesDistractor17 {
    func typesCallAsFunction() {}
}

public class FixtureTypesUser17 {
    public func entry() {
        #if os(iOS)
        let value: FixtureTypesStruct17 = FixtureTypesStruct17()
        value.typesCallAsFunction()
        #endif
    }
}
