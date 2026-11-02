@dynamicCallable
struct Multiplier {}

extension Multiplier {
    func dynamicallyCall(withArguments args: [Int]) -> Int { args.reduce(1, *) }
}

// periphery:ignore
func retainMultiplier() {
    _ = Multiplier()(2, 3)
}
