open class OpenFinalClassSubclassedCrossModule {
    public init() {}

    open func openFinalOverriddenCrossModule() {}
    open func openFinalNeverOverriddenMember() {}
}

open class OpenFinalClassNeverSubclassed {
    public init() {}

    open func openFinalMemberOfNeverSubclassedClass() {}
}

public class OpenFinalPublicClassWithOpenMember {
    public init() {}

    open func openFinalOpenMemberInPublicClass() {}
}

class OpenFinalInternalClassWithoutSubclass {
    func openFinalMemberOfClassWithoutSubclass() {}
}

class OpenFinalInternalClassWithSubclass {
    let openFinalLetProperty = 1
    var openFinalVarProperty = 1
    var openFinalComputedProperty: Int { 1 }

    func openFinalOverriddenMember() {}
    func openFinalNotOverriddenMember() {}
}

final class OpenFinalInternalSubclass: OpenFinalInternalClassWithSubclass {
    override func openFinalOverriddenMember() {}
}

final class OpenFinalAlreadyFinalClass {
    func openFinalMemberOfFinalClass() {}
}

actor OpenFinalActor {
    func openFinalActorMember() {}
}

public enum OpenFinalRetainer {
    public static func retain() {
        OpenFinalInternalClassWithoutSubclass().openFinalMemberOfClassWithoutSubclass()
        let base: OpenFinalInternalClassWithSubclass = OpenFinalInternalSubclass()
        base.openFinalOverriddenMember()
        base.openFinalNotOverriddenMember()
        base.openFinalVarProperty = base.openFinalLetProperty + base.openFinalComputedProperty
        _ = base.openFinalVarProperty
        OpenFinalAlreadyFinalClass().openFinalMemberOfFinalClass()
        _ = OpenFinalActor()
        OpenFinalClassNeverSubclassed().openFinalMemberOfNeverSubclassedClass()
        OpenFinalPublicClassWithOpenMember().openFinalOpenMemberInPublicClass()
    }
}
