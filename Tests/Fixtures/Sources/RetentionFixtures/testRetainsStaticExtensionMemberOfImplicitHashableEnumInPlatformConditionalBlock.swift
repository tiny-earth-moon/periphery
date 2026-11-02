import Foundation

extension Hashable {
    static func fixtureSyntax06Make() {}
}

enum FixtureSyntax06Enum {
    case first
}

struct FixtureSyntax06Decoy {
    static func fixtureSyntax06Make() {}
}

public class FixtureSyntax06Entry {
    public func entry() {
        _ = FixtureSyntax06Enum.first
        _ = FixtureSyntax06Decoy()
        #if os(iOS)
        FixtureSyntax06Enum.fixtureSyntax06Make()
        #endif
    }
}
