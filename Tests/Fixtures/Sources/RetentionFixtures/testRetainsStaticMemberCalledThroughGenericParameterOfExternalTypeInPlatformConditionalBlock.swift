import Foundation

protocol FixtureSyntax05Proto {}

extension FixtureSyntax05Proto {
    static func make05() {}
}

struct FixtureSyntax05Impl: FixtureSyntax05Proto {}

// A project type named like the generic parameter of `Result`.
struct Success {
    static func make05() {}
}

extension Result where Success: FixtureSyntax05Proto {
    func run05() {
        #if os(iOS)
        Success.make05()
        #endif
    }
}

public class FixtureSyntax05Entry {
    public func entry() {
        let result: Result<FixtureSyntax05Impl, Error> = .success(FixtureSyntax05Impl())
        result.run05()
        _ = Success()
    }
}
