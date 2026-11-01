import Foundation

public protocol RpmProtocol {
    func rpmRequirement()
    var rpmRequirementProperty: Int { get }
}

public struct RpmPublicStruct: RpmProtocol, Equatable, CustomStringConvertible, Decodable {
    public init() {}

    public init(from _: Decoder) throws {}

    public func rpmUsedCrossModule() {}
    public func rpmNotUsedCrossModule() {}
    public var rpmPropertyNotUsedCrossModule: Int { 0 }
    public func rpmUsedByTestsOnly() {}
    public func rpmRequirement() {}
    public var rpmRequirementProperty: Int { 0 }
    public var description: String { "" }
    @inlinable public func rpmInlinable() {}

    public static func == (_: Self, _: Self) -> Bool { true }

    public struct RpmNestedNotUsedCrossModule {
        public func rpmMemberOfRedundantNested() {}
    }
}

extension RpmPublicStruct {
    public func rpmInExtensionNotUsedCrossModule() {}
    public func rpmInExtensionUsedCrossModule() {}
}

open class RpmOpenClass {
    public init() {}

    open func rpmOpenMember() {}
    public func rpmPublicMemberOfOpenClass() {}
}

public enum RpmPublicEnum {
    case rpmCase
}

public func rpmRetain() throws -> RpmPublicStruct {
    let value = RpmPublicStruct()
    value.rpmNotUsedCrossModule()
    _ = value.rpmPropertyNotUsedCrossModule
    value.rpmUsedByTestsOnly()
    let requirements: RpmProtocol = value
    requirements.rpmRequirement()
    _ = requirements.rpmRequirementProperty
    _ = value.description
    _ = value == value
    value.rpmInlinable()
    RpmPublicStruct.RpmNestedNotUsedCrossModule().rpmMemberOfRedundantNested()
    value.rpmInExtensionNotUsedCrossModule()
    _ = try JSONDecoder().decode(RpmPublicStruct.self, from: Data("{}".utf8))
    let openClass = RpmOpenClass()
    openClass.rpmOpenMember()
    openClass.rpmPublicMemberOfOpenClass()
    _ = RpmPublicEnum.rpmCase
    return value
}
