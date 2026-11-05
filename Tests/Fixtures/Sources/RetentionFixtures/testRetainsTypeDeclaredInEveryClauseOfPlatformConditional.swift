#if os(macOS) || os(Linux)
struct FixturePlatformSpecificView {
    func platformSpecificTitle() -> String { "desktop" }
}
#else
struct FixturePlatformSpecificView {
    func platformSpecificTitle() -> String { "mobile" }
}
#endif

public class FixturePlatformSpecificViewUser {
    public func entry() -> String {
        #if os(macOS) || os(Linux)
        FixturePlatformSpecificView().platformSpecificTitle()
        #else
        FixturePlatformSpecificView().platformSpecificTitle() + "!"
        #endif
    }
}
