import Foundation

public func platformSystemUse() -> Int {
    #if os(iOS)
    return ProcessInfo.processInfo.processIdentifier
    #else
    return 0
    #endif
}
