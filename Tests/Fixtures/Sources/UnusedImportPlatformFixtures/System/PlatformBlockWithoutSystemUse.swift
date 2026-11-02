import Foundation

public func platformBlockWithoutSystemUse() -> Int {
    #if os(iOS)
    return localSystemPlatformHelper()
    #else
    return 0
    #endif
}

func localSystemPlatformHelper() -> Int { 4 }
