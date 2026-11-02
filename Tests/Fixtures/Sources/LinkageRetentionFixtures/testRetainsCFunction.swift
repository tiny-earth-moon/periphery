@c
func exportedWithC() -> Int32 { 1 }

@c(fixture_named_c)
func exportedWithNamedC() {}

func plainAfterC() -> Int32 { 2 }
