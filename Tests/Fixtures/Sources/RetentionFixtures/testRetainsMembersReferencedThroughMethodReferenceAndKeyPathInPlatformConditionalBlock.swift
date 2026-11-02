import Foundation

class FixtureSyntax09Base {
    func ref09() {}
    var path09 = 0
    func label09(_ value: Int) { _ = value }
}

final class FixtureSyntax09Sub: FixtureSyntax09Base {}

struct FixtureSyntax09Decoy {
    func ref09() {}
    var path09 = 0
    func label09(_ value: Int) { _ = value }
}

public class FixtureSyntax09Entry {
    public func entry() {
        _ = FixtureSyntax09Sub()
        _ = FixtureSyntax09Decoy()
        #if os(iOS)
        let method = FixtureSyntax09Sub.ref09
        let keyPath = \FixtureSyntax09Sub.path09
        let labelled = FixtureSyntax09Sub.label09(_:)
        _ = (method, keyPath, labelled)
        #endif
    }
}
