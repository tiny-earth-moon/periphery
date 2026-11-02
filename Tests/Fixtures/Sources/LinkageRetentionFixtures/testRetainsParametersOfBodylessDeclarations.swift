@_silgen_name("fixture_silgen_imported_used")
func importedWithSilgenName(_ first: Int, _ second: Int) -> Int

@_extern(c, "abs")
func importedWithExtern(_ value: Int32) -> Int32

func callImports() -> Int {
    importedWithSilgenName(1, 2) + Int(importedWithExtern(3))
}

// A function with a body still reports its unused parameters.
func definedWithUnusedParameter(_ value: Int) {}

// periphery:ignore
func retainCallers() {
    _ = callImports()
    definedWithUnusedParameter(1)
}
