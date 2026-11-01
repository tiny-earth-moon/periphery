public class FixtureUnassignedOptionalWithoutOption {
    var neverAssigned: Int?

    public init() {}

    public func read() {
        print(neverAssigned as Any)
    }
}
