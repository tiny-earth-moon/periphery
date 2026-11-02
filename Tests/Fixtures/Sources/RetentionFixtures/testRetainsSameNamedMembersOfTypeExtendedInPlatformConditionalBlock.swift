import Foundation

protocol FixtureProtocol252 {}

extension FixtureProtocol252 {
    func prepare() {}
}

public struct FixtureStruct252 {}

public struct FixtureStruct253: FixtureProtocol252 {}

public struct FixtureStruct254 {
    func prepare() {}
}

#if os(iOS)
extension FixtureStruct252: FixtureProtocol252 {}
#endif

public class FixtureClass252 {
    public func entry() {
        #if os(iOS)
        FixtureStruct252().prepare()
        #endif
    }
}
