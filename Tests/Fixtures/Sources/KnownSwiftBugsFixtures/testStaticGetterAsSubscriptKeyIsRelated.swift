enum FixtureEnumSubscript {
    static let someVar = ""
}

public class FixtureClassSubscript {
    public func someFunc() {
        var s: [String: Int] = [:]
        s[FixtureEnumSubscript.someVar] = 0
    }
}
