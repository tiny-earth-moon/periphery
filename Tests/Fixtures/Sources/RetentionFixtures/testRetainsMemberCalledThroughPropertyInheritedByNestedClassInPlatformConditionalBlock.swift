import Foundation

final class FixtureSyntax17Other {
    func start17() {}
}

final class FixtureSyntax17Engine {
    func start17() {}
}

class FixtureSyntax17Base {
    let engine17 = FixtureSyntax17Other()
}

public struct FixtureSyntax17Outer {
    #if os(iOS)
    var engine17: FixtureSyntax17Engine = FixtureSyntax17Engine()

    final class Child17: FixtureSyntax17Base {
        func go17() {
            engine17.start17()
        }
    }
    #endif

    public init() {
        _ = FixtureSyntax17Base().engine17
    }
}
