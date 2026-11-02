import UnusedImportPlatformSupportFixtures

public func platformOnlyUse() -> Int {
    #if os(iOS)
    return platformOnlyHelper()
    #else
    return 0
    #endif
}
