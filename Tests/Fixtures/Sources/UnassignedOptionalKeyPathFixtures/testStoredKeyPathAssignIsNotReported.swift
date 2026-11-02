#if canImport(Combine)
    import Combine

    public class FixtureStoredKeyPathAssignTarget {
        var viaAssign: Int?
        var neverAssigned: Int?

        public init() {}
    }

    public func fixtureStoredKeyPathAssignRun() {
        let target = FixtureStoredKeyPathAssignTarget()
        _ = Just<Int?>(4).assign(to: \.viaAssign, on: target)
        print(target.viaAssign as Any, target.neverAssigned as Any)
    }
#endif
