@dynamicCallable
struct Adder {
    func dynamicallyCall(withArguments args: [Int]) -> Int { args.reduce(0, +) }
    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Int>) -> Int { args.count }
    func plainMethod() {}
}

func runAdder() -> Int {
    let add = Adder()
    return add(1, 2, 3) + add(a: 1)
}

// periphery:ignore
func retainAdder() {
    _ = runAdder()
}
