import Foundation

struct FixturePlatformExtendedStruct {}

fileprivate protocol FixturePlatformDeclaredProtocol {}

fileprivate typealias FixturePlatformDeclaredAlias = Int

struct FixturePlatformUsedStruct {}

#if canImport(Foundation)
extension FixturePlatformExtendedStruct: @unchecked Sendable {}

fileprivate func fixturePlatformDeclaredFunction() {}
#endif

public func fixturePlatformEntry() {
    #if os(Windows)
    _ = FixturePlatformUsedStruct()
    #endif
}
