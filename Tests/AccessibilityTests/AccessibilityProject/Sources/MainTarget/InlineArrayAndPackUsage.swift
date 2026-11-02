import TargetA

// periphery:ignore
func retainPacks() {
    _ = publicPackReturn(1, "a")
    publicPackParameter()
}

// periphery:ignore
@available(macOS 26, iOS 26, *)
func retainInlineArrays() {
    _ = publicInlineArrayReturn()
    _ = publicInlineArrayParameter
    _ = publicInlineArrayVariable
}
