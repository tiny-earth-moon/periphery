import Foundation

public struct FixtureStruct250 {
    static func make() -> FixtureStruct250 { FixtureStruct250() }
    static func reset() {}
    func load() {}
    func store() {}
    func reload() {}
    func refresh() {}
}

public struct FixtureStruct251 {
    static func make() -> FixtureStruct251 { FixtureStruct251() }
    static func reset() {}
    func load() {}
    func store() {}
    func reload() {}
    func refresh() {}
}

typealias FixtureAlias250 = FixtureStruct250

public class FixtureClass250 {
    class func reset() {}
    func reload() {}
    func refresh() {}

    public func entry() {
        #if os(iOS)
        let made: FixtureStruct250 = .make()
        let value = FixtureStruct250()
        value.load()
        FixtureAlias250().store()
        self.reload()
        refresh()
        #endif
    }

    public func run<Subject: FixtureClass250>(_: Subject.Type) {
        #if os(iOS)
        Subject.reset()
        #endif
    }
}
