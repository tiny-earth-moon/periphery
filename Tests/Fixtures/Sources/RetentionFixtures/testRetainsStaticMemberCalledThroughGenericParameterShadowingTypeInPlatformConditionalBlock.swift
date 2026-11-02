import Foundation

protocol FixtureSyntax04Proto {}

extension FixtureSyntax04Proto {
    static func make04() {}
    static func make04b() {}
}

struct FixtureSyntax04Item {
    static func make04() {}
    static func make04b() {}
}

struct FixtureSyntax04Impl: FixtureSyntax04Proto {}

struct FixtureSyntax04Box<FixtureSyntax04Item: FixtureSyntax04Proto> {
    func run() {
        #if os(iOS)
        FixtureSyntax04Item.make04b()
        #endif
    }
}

public class FixtureSyntax04Entry {
    func run<FixtureSyntax04Item: FixtureSyntax04Proto>(_: FixtureSyntax04Item.Type) {
        #if os(iOS)
        FixtureSyntax04Item.make04()
        #endif
    }

    public func entry() {
        run(FixtureSyntax04Impl.self)
        FixtureSyntax04Box<FixtureSyntax04Impl>().run()
    }
}
