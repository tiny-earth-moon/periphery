public class FixtureTypesG2A {
    func typesG2() {}
}

public class FixtureTypesG2B: FixtureTypesG2A {
    override func typesG2() {}
}

public class FixtureTypesG2C: FixtureTypesG2B {
    override func typesG2() {}
}

public struct FixtureTypesG2Distractor {
    func typesG2() {}
}

public class FixtureTypesG2User {
    public func entry() {
        #if os(iOS)
        let value: FixtureTypesG2A = FixtureTypesG2C()
        value.typesG2()
        #endif
    }
}
