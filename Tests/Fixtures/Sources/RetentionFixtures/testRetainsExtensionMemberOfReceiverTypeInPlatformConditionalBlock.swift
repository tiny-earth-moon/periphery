import Foundation

public struct FixtureStruct242 {}

extension FixtureStruct242 {
    func prepare() {}
}

public struct FixtureStruct243 {
    func prepare() {}
}

public class FixtureClass242 {
    public func entry() {
        #if os(iOS)
        FixtureStruct242().prepare()
        #endif
    }
}
