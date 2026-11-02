import Foundation

struct FixtureSyntax13A {
    func fetch13() {}
}

struct FixtureSyntax13Other {
    func fetch13() {}
}

public struct FixtureSyntax13Holder {
    static var store13 = FixtureSyntax13Other()

    #if os(iOS)
    var store13: FixtureSyntax13A = FixtureSyntax13A()

    static func reload13() {
        store13.fetch13()
    }
    #endif

    public init() {
        _ = Self.store13
    }
}
