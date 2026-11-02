import UnusedImportPlatformSupportFixtures

public func platformOnlyModuleQualifiedUse() -> Int {
    #if os(iOS)
    return UnusedImportPlatformSupportFixtures.unrelatedSupportHelper()
    #else
    return 0
    #endif
}
