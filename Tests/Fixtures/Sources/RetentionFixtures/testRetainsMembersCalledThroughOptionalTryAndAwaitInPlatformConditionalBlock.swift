import Foundation

struct FixtureSyntax11Target {
    func optA() {}
    func optB() {}
    func optC() {}
    func optD() {}
}

final class FixtureSyntax11Service {
    static var maybe11: FixtureSyntax11Target? = FixtureSyntax11Target()
    static var forced11: FixtureSyntax11Target! = FixtureSyntax11Target()
    static func throwing11() throws -> FixtureSyntax11Target { FixtureSyntax11Target() }
    static func async11() async -> FixtureSyntax11Target { FixtureSyntax11Target() }

    func optA() {}
    func optB() {}
    func optC() {}
    func optD() {}
}

public class FixtureSyntax11Entry {
    public func entry() async throws {
        _ = FixtureSyntax11Service()
        _ = FixtureSyntax11Service.maybe11
        _ = FixtureSyntax11Service.forced11
        _ = try FixtureSyntax11Service.throwing11()
        _ = await FixtureSyntax11Service.async11()
        #if os(iOS)
        FixtureSyntax11Service.maybe11?.optA()
        FixtureSyntax11Service.forced11!.optB()
        try FixtureSyntax11Service.throwing11().optC()
        await FixtureSyntax11Service.async11().optD()
        #endif
    }
}
