import Foundation

struct FixtureSyntax16Model {
    func title16() -> String { "" }
    func closure16() {}
    func trailing16() {}
    func selfUse16() {}
    static func staticUse16() {}
}

struct FixtureSyntax16Decoy {
    func title16() -> String { "" }
    func closure16() {}
    func trailing16() {}
    func selfUse16() {}
    static func staticUse16() {}
}

extension FixtureSyntax16Model {
    func entry16() {
        #if os(iOS)
        print("\(FixtureSyntax16Model().title16())")
        [1].forEach { _ in FixtureSyntax16Model().closure16() }
        DispatchQueue.main.async {
            FixtureSyntax16Model().trailing16()
        }
        self.selfUse16()
        Self.staticUse16()
        #endif
    }
}

public class FixtureSyntax16Entry {
    public func entry() {
        _ = FixtureSyntax16Decoy()
        FixtureSyntax16Model().entry16()
    }
}
