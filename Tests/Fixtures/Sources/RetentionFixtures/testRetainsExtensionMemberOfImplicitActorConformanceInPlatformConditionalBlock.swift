extension Actor {
    nonisolated func typesActor() {}
}

public actor FixtureTypesActor9 {}

public struct FixtureTypesDistractor9 {
    func typesActor() {}
}

public class FixtureTypesUser9 {
    public func entry() {
        #if os(iOS)
        FixtureTypesActor9().typesActor()
        #endif
    }
}
