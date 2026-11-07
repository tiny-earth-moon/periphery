@_cdecl("fixture_cdecl_with_parameters")
func exportedWithCdeclParameters(_ first: Int32, _ unusedSecond: Int32) -> Int32 { first }

func plainWithUnusedParameter(_ value: Int32) -> Int32 { 0 }

public func fixtureCdeclParametersRoot() {
    _ = plainWithUnusedParameter(1)
}
