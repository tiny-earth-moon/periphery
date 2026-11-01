public class FixtureUnassignedOptionalAssigned {
    var assignedInInit: Int?
    var assignedInMethod: Int?
    var assignedViaSelfInMethod: Int?
    var assignedInClosure: Int?
    var assignedViaInout: Int?
    var assignedViaKeyPath: Int?
    var withInitialValue: Int? = 1
    var nonOptional: Int = 0
    let constant: Int?

    public init() {
        assignedInInit = 1
        constant = nil
    }

    public func assign() {
        assignedInMethod = 1
        self.assignedViaSelfInMethod = 1
        [1].forEach { self.assignedInClosure = $0 }
        mutate(&assignedViaInout)
        self[keyPath: \FixtureUnassignedOptionalAssigned.assignedViaKeyPath] = 1
    }

    public func read() {
        print(assignedInInit as Any)
        print(assignedInMethod as Any)
        print(assignedViaSelfInMethod as Any)
        print(assignedInClosure as Any)
        print(assignedViaInout as Any)
        print(assignedViaKeyPath as Any)
        print(withInitialValue as Any)
        print(nonOptional)
        print(constant as Any)
    }

    private func mutate(_ value: inout Int?) {
        value = 1
    }
}
