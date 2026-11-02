import TargetA

func retainOneLineDeclarations() {
    let _: OneLineCaseHolder? = nil
    let _: MultiLineCaseHolder? = nil
    let _: OneLineLabeledCaseHolder? = nil
    let _: MultiLineLabeledCaseHolder? = nil
    _ = OneLineSubscriptHolder()
    _ = MultiLineSubscriptHolder()
    _ = OneLineTypealiasHolder()
    _ = MultiLineTypealiasHolder()
    _ = OneLineControlHolder()
}
