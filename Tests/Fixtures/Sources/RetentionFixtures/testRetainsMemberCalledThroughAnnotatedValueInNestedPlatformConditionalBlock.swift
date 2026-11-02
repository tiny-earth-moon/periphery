import Foundation

class FixtureSyntax12Base {
    func draw12() {}
}

final class FixtureSyntax12Sub: FixtureSyntax12Base {
    override func draw12() {}
}

struct FixtureSyntax12Decoy {
    func draw12() {}
}

public class FixtureSyntax12Entry {
    public func entry() {
        _ = FixtureSyntax12Decoy()
        #if canImport(AppKit)
        let view: FixtureSyntax12Base = FixtureSyntax12Sub()
        #if os(iOS)
        view.draw12()
        #endif
        _ = view
        #endif
    }
}
