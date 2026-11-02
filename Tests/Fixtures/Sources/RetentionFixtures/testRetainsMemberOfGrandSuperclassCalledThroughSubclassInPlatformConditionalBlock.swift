public class FixtureTypesG1A {
    func typesG1() {}
}

public class FixtureTypesG1B: FixtureTypesG1A {}

public class FixtureTypesG1C: FixtureTypesG1B {}

public struct FixtureTypesG1Distractor {
    func typesG1() {}
}

public class FixtureTypesG1User {
    public func entry() {
        #if os(iOS)
        FixtureTypesG1C().typesG1()
        #endif
    }
}
