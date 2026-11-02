import DynamicCallableSupportFixtures

// periphery:ignore
func useDynamicCaller() -> Int {
    DynamicCaller()(1, 2) + DynamicCaller()(a: 1)
}
