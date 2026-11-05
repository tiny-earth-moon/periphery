protocol FixtureProtocol223Style {}

struct FixtureStruct223UsedStyle: FixtureProtocol223Style {}
struct FixtureStruct223UnusedStyle: FixtureProtocol223Style {}

enum FixtureEnum223Namespace {
    struct UsedNestedStyle: FixtureProtocol223Style {}
    struct UnusedNestedStyle: FixtureProtocol223Style {}
}

extension FixtureProtocol223Style where Self == FixtureStruct223UsedStyle {
    static var usedStyle: FixtureStruct223UsedStyle { FixtureStruct223UsedStyle() }
}

extension FixtureProtocol223Style where Self == FixtureStruct223UnusedStyle {
    static var unusedStyle: FixtureStruct223UnusedStyle { FixtureStruct223UnusedStyle() }
}

extension FixtureProtocol223Style where Self == FixtureEnum223Namespace.UsedNestedStyle {
    static var usedNestedStyle: FixtureEnum223Namespace.UsedNestedStyle { .init() }
}

extension FixtureProtocol223Style where Self == FixtureEnum223Namespace.UnusedNestedStyle {
    static var unusedNestedStyle: FixtureEnum223Namespace.UnusedNestedStyle { .init() }
}

func fixture223Apply(_: some FixtureProtocol223Style) -> Int { 1 }

public func fixture223Retainer() {
    _ = fixture223Apply(.usedStyle)
    _ = fixture223Apply(.usedNestedStyle)
}
