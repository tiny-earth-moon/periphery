#if os(iOS)
    func phoneNeverCalled() -> Int {
        4
    }

    func phoneCalled() -> Int {
        5
    }
#endif

public func inBlock() -> Int {
    #if os(iOS)
        phoneCalled()
    #else
        0
    #endif
}
