import Foundation

public protocol ExternalWitnessRepresentable: RawRepresentable, CaseIterable, Identifiable, Hashable, Sendable where RawValue == String {}

public extension ExternalWitnessRepresentable {
    var id: String {
        rawValue
    }
}

public enum ExternalWitnessItem: String, ExternalWitnessRepresentable {
    case a
}

// Control: the extension member does not witness an external requirement.
public protocol ExternalWitnessControlProtocol {}

public extension ExternalWitnessControlProtocol {
    func controlHelper() {}
}

public struct ExternalWitnessControlType: ExternalWitnessControlProtocol {
    public init() {}
}

// Control: no public type conforms, so nothing requires the witness to be public.
public protocol ExternalWitnessUnadoptedProtocol: Identifiable {}

public extension ExternalWitnessUnadoptedProtocol {
    var id: String {
        "a"
    }
}

// periphery:ignore
let externalWitnessUnadoptedAnchor: (any ExternalWitnessUnadoptedProtocol)? = nil

// Twin: the witnessed requirement belongs to a local public protocol, which needs no external protocol.
public protocol ExternalWitnessLocalRequirement {
    var label: String { get }
}

public protocol ExternalWitnessLocalRefining: ExternalWitnessLocalRequirement {}

public extension ExternalWitnessLocalRefining {
    var label: String {
        "a"
    }
}

public struct ExternalWitnessLocalConformer: ExternalWitnessLocalRefining {
    public init() {}
}
