struct FixtureCompiledClauseAlpha {
    func compiledClauseDraw() -> Int { 1 }
}

struct FixtureCompiledClauseBeta {
    func compiledClauseDraw() -> Int { 2 }
    func compiledClauseUnused() -> Int { 3 }
}

struct FixtureCompiledClauseGamma {
    func compiledClausePaint() -> Int { 4 }
}

struct FixtureCompiledClauseDelta {
    func compiledClausePaint() -> Int { 5 }
}

public class FixtureCompiledClauseUser {
    public func entry() -> Int {
        var count = 0

        // The compiled clause is in the index store; the declaration in the other clause names no reference.
        #if os(macOS) || os(Linux)
        count += FixtureCompiledClauseAlpha().compiledClauseDraw()
        #else
        struct OtherPlatformDrawer {
            func compiledClauseDraw() -> Int { 0 }
        }
        #endif

        // A clause that was not compiled may call either member.
        #if os(iOS)
        count += FixtureCompiledClauseGamma().compiledClausePaint()
        #endif

        _ = FixtureCompiledClauseBeta()
        _ = FixtureCompiledClauseDelta()
        return count
    }
}
