import Foundation

public struct FixtureStruct240 {
    struct Inner {
        func reload() {}
    }
}

public struct FixtureStruct241 {
    public struct Inner {
        func reload() {}
    }
}

public class FixtureClass240 {
    public func entry() {
        #if os(iOS)
        FixtureStruct240.Inner().reload()
        #endif
    }
}
