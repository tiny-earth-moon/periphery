@dynamicCallable
public struct DynamicCaller {
    public init() {}

    public func dynamicallyCall(withArguments args: [Int]) -> Int { args.count }
    public func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Int>) -> Int { args.count }
    public func plainPublicMethod() {}
}

extension DynamicCaller {
    public func usedOnlyInsideModule() {}
}

// periphery:ignore
func useWithinSupportModule() {
    DynamicCaller().usedOnlyInsideModule()
    _ = DynamicCaller().dynamicallyCall(withKeywordArguments: [:])
}
