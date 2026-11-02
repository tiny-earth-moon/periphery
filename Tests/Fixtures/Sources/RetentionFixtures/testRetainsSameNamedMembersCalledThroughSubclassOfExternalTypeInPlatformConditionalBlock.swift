import Foundation

public class FixtureClass255: NSObject {}

extension NSObject {
    func fixtureConfigure() {}
}

public struct FixtureStruct255 {
    func fixtureConfigure() {}
}

public class FixtureClass256 {
    public func entry() {
        #if os(iOS)
        FixtureClass255().fixtureConfigure()
        #endif
    }
}
