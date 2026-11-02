import UnusedImportPlatformSupportFixtures

public func platformBlockWithoutModuleUse() -> Int {
    #if os(iOS)
    return localPlatformHelper()
    #else
    return 0
    #endif
}

func localPlatformHelper() -> Int { 3 }
