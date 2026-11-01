public class FixtureUnassignedOptionalRead {
    static var sharedNeverAssigned: Int?
    var neverAssigned: Int?
    var neverAssignedImplicitlyUnwrapped: String!
    var neverAssignedGeneric: Optional<Double> = nil
    var nilInitialized: Int? = nil

    public init() {}

    public func read() {
        print(Self.sharedNeverAssigned as Any)
        print(neverAssigned as Any)
        print(neverAssignedImplicitlyUnwrapped as Any)
        print(neverAssignedGeneric as Any)
        print(nilInitialized as Any)
    }
}
