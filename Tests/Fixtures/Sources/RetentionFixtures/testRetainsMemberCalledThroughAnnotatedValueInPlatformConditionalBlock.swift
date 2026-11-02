import Foundation

public struct FixtureStruct246 {
    func apply() {}
}

public struct FixtureStruct247 {
    func apply() {}
}

public class FixtureClass246 {
    public func entry() {
        #if os(iOS)
        let item: FixtureStruct246 = FixtureStruct246()
        item.apply()
        #endif
    }
}
