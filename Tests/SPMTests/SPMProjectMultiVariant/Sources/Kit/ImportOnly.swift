import Util

public func importOnly() -> Int {
    #if os(iOS)
        utilOnlyOnPhone()
    #else
        0
    #endif
}
