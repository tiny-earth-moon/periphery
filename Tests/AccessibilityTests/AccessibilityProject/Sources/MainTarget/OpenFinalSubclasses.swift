import TargetA

final class OpenFinalCrossModuleSubclass: OpenFinalClassSubclassedCrossModule {
    override func openFinalOverriddenCrossModule() {}
}

func openFinalRetain() {
    let object: OpenFinalClassSubclassedCrossModule = OpenFinalCrossModuleSubclass()
    object.openFinalOverriddenCrossModule()
    object.openFinalNeverOverriddenMember()
    OpenFinalRetainer.retain()
}
