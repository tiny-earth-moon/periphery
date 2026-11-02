import Foundation

struct FixtureSyntax10Product {
    func useA() {}
    func useB() {}
    func useC() {}
    func useD() {}
}

struct FixtureSyntax10Box<T> {
    static func make() -> FixtureSyntax10Product { FixtureSyntax10Product() }
    func useD() {}
}

struct FixtureSyntax10Factory {
    static let shared10 = FixtureSyntax10Factory()
    static func make10() -> FixtureSyntax10Product { FixtureSyntax10Product() }
    func child10() -> FixtureSyntax10Product { FixtureSyntax10Product() }
    var product10: FixtureSyntax10Product { FixtureSyntax10Product() }

    func useA() {}
    func useB() {}
    func useC() {}
}

public class FixtureSyntax10Entry {
    public func entry() {
        _ = FixtureSyntax10Factory.make10()
        _ = FixtureSyntax10Factory.shared10.child10()
        _ = FixtureSyntax10Factory().product10
        _ = FixtureSyntax10Box<Int>.make()
        #if os(iOS)
        FixtureSyntax10Factory.make10().useA()
        FixtureSyntax10Factory.shared10.product10.useB()
        FixtureSyntax10Factory().child10().useC()
        FixtureSyntax10Box<Int>.make().useD()
        #endif
    }
}
