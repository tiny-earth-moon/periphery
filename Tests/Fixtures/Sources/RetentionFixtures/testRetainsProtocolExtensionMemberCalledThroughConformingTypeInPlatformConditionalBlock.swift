import Foundation

protocol FixtureProtocol237 {
    func describe()
}

extension FixtureProtocol237 {
    func describe() {}
}

protocol FixtureProtocol238 {}

extension FixtureProtocol238 {
    func summarize() {}
}

protocol FixtureProtocol239: FixtureProtocol238 {}

public struct FixtureStruct237: FixtureProtocol237, FixtureProtocol239 {}

public struct FixtureStruct238 {
    func describe() {}
    func summarize() {}
}

public class FixtureClass239 {
    public func entry() {
        #if os(iOS)
        FixtureStruct237().describe()
        FixtureStruct237().summarize()
        #endif
    }
}
