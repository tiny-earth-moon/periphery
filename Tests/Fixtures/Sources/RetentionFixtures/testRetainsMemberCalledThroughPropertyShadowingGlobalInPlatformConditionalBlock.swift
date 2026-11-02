import Foundation

final class FixtureSyntax14Logger {
    func log14() {}
}

final class FixtureSyntax14Other {
    func log14() {}
}

public final class FixtureSyntax14Host {
    let logger14 = FixtureSyntax14Other()

    public init() {
        _ = logger14
    }
}

#if os(iOS)
let logger14: FixtureSyntax14Logger = FixtureSyntax14Logger()

extension FixtureSyntax14Host {
    func report14() {
        logger14.log14()
    }
}
#endif
