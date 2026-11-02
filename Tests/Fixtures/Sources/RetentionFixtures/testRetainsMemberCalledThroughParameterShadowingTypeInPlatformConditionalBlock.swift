import Foundation

struct FixtureSyntax02Shadow {
    func run02() {}
}

public struct FixtureSyntax02Other {
    func run02() {}
}

public class FixtureSyntax02Entry {
    public func entry(_ FixtureSyntax02Shadow: FixtureSyntax02Other) {
        #if os(iOS)
        FixtureSyntax02Shadow.run02()
        #endif
        _ = FixtureSyntax02Shadow
    }

    public func start() {
        entry(FixtureSyntax02Other())
    }
}
