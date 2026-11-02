import Foundation

struct FixtureSyntax03Shadow {
    func run03() {}
}

struct FixtureSyntax03Other {
    func run03() {}
}

public class FixtureSyntax03Entry {
    public func entry() {
        typealias FixtureSyntax03Shadow = FixtureSyntax03Other
        _ = FixtureSyntax03Other()
        #if os(iOS)
        FixtureSyntax03Shadow().run03()
        #endif
    }
}
