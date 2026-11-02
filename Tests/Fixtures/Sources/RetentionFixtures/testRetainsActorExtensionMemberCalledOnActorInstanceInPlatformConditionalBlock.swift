import Foundation

extension Actor {
    nonisolated func fixtureSyntax08Run() {}
}

actor FixtureSyntax08Actor {}

struct FixtureSyntax08Decoy {
    func fixtureSyntax08Run() {}
}

public class FixtureSyntax08Entry {
    public func entry() {
        _ = FixtureSyntax08Actor()
        _ = FixtureSyntax08Decoy()
        #if os(iOS)
        FixtureSyntax08Actor().fixtureSyntax08Run()
        #endif
    }
}
