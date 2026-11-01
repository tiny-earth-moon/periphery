internal func ralInternalTopLevelFunction() {}
func ralImplicitTopLevelFunction() {}
fileprivate func ralFileprivateTopLevelFunction() {}

public struct RalPublicStruct {
    public init() {}

    internal func ralInternalInPublicStruct() {}
    public func ralPublicInPublicStruct() {}
    internal(set) public var ralPublicVarWithInternalSetter = 0
}

struct RalInternalStruct {
    internal var ralInternalInInternalStruct = 0
    internal(set) var ralInternalSetterVar = 0
    private var ralPrivateInInternalStruct = 0
    fileprivate func ralFileprivateInInternalStruct() {}

    func ralUsePrivates() -> Int {
        ralPrivateInPrivateExtension()
        ralPrivateInFileprivateExtension()
        return ralPrivateInInternalStruct
    }
}

private struct RalPrivateStruct {
    fileprivate func ralFileprivateInPrivateStruct() {}
    private func ralPrivateInPrivateStruct() {}

    func ralUsePrivate() {
        ralPrivateInPrivateStruct()
    }

    struct RalNestedInPrivateStruct {
        fileprivate func ralFileprivateInNestedOfPrivateStruct() {}
    }
}

fileprivate struct RalFileprivateStruct {
    fileprivate func ralFileprivateInFileprivateStruct() {}
}

struct RalOuterStruct {
    private struct RalPrivateNestedStruct {
        fileprivate func ralFileprivateInPrivateNestedStruct() {}
    }

    func ralUsePrivateNested() {
        RalPrivateNestedStruct().ralFileprivateInPrivateNestedStruct()
    }
}

extension RalInternalStruct {
    internal func ralInternalInImplicitExtension() {}
}

public extension RalPublicStruct {
    public func ralPublicInPublicExtension() {}
    internal func ralInternalInPublicExtension() {}
}

private extension RalInternalStruct {
    private func ralPrivateInPrivateExtension() {}
    fileprivate func ralFileprivateInPrivateExtension() {}
}

fileprivate extension RalInternalStruct {
    private func ralPrivateInFileprivateExtension() {}
}

struct RalInternalExtended {}

internal extension RalInternalExtended {
    func ralImplicitInInternalExtension() {}
}

open class RalOpenClass {
    public init() {}

    open func ralOpenInOpenClass() {}
    internal func ralInternalInOpenClass() {}
}

public protocol RalPublicProtocol {
    func ralProtocolRequirement()
}

public extension RalPublicProtocol {
    public func ralPublicInPublicProtocolExtension() {}
}

extension RalPublicStruct: RalPublicProtocol {
    public func ralProtocolRequirement() {}
}

public enum RalPublicEnum {
    case ralCase

    internal static func ralInternalInPublicEnum() {}
}

extension String {
    internal func ralInternalInExternalTypeExtension() {}
}

public func redundantAccessLevelRetain() {
    ralInternalTopLevelFunction()
    ralImplicitTopLevelFunction()
    ralFileprivateTopLevelFunction()

    let publicStruct = RalPublicStruct()
    publicStruct.ralInternalInPublicStruct()
    publicStruct.ralPublicInPublicStruct()
    _ = publicStruct.ralPublicVarWithInternalSetter
    publicStruct.ralPublicInPublicExtension()
    publicStruct.ralInternalInPublicExtension()
    publicStruct.ralPublicInPublicProtocolExtension()
    let existential: any RalPublicProtocol = publicStruct
    existential.ralProtocolRequirement()

    let internalStruct = RalInternalStruct()
    _ = internalStruct.ralInternalInInternalStruct
    _ = internalStruct.ralInternalSetterVar
    internalStruct.ralFileprivateInInternalStruct()
    _ = internalStruct.ralUsePrivates()
    internalStruct.ralInternalInImplicitExtension()
    internalStruct.ralFileprivateInPrivateExtension()

    let privateStruct = RalPrivateStruct()
    privateStruct.ralFileprivateInPrivateStruct()
    privateStruct.ralUsePrivate()
    RalPrivateStruct.RalNestedInPrivateStruct().ralFileprivateInNestedOfPrivateStruct()
    RalFileprivateStruct().ralFileprivateInFileprivateStruct()
    RalOuterStruct().ralUsePrivateNested()
    RalInternalExtended().ralImplicitInInternalExtension()

    let openClass = RalOpenClass()
    openClass.ralOpenInOpenClass()
    openClass.ralInternalInOpenClass()

    _ = RalPublicEnum.ralCase
    RalPublicEnum.ralInternalInPublicEnum()
    "".ralInternalInExternalTypeExtension()
}
