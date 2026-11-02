import Foundation

public struct FixtureStruct244 {
    static let fallback = 1
    static func makeFixture() {}
}

public struct FixtureStruct245 {
    static let fallback = 2
    static func makeFixture() {}
}

public class FixtureClass244 {
    public func entry() {
        #if os(iOS)
        _ = FixtureStruct244.fallback
        FixtureStruct244.makeFixture()
        #endif
    }
}
