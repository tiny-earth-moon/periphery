import Foundation

struct FixtureSyntax01Shadow {
    func run01() {}
}

struct FixtureSyntax01Other {
    func run01() {}
}

public class FixtureSyntax01Entry {
    public func entry() {
        let FixtureSyntax01Shadow = FixtureSyntax01Other()
        #if os(iOS)
        FixtureSyntax01Shadow.run01()
        #endif
        _ = FixtureSyntax01Shadow
    }
}
