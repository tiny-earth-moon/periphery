import Foundation

public class FixtureClass236 {
    func refresh() {}
}

public class FixtureClass237: FixtureClass236 {}

public struct FixtureStruct236 {
    func refresh() {}
}

public class FixtureClass238 {
    public func entry() {
        #if os(iOS)
        FixtureClass237().refresh()
        #endif
    }
}
