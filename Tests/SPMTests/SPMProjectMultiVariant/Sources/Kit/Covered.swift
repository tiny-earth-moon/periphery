struct Gamma {
    @available(iOS, unavailable)
    func macOnlyNeverCalled() -> Int {
        6
    }

    @available(iOS, unavailable)
    func macOnlyCalled() -> Int {
        7
    }
}

struct Delta {
    func paint() -> Int {
        8
    }
}

struct Epsilon {
    func paint() -> Int {
        9
    }
}

public func covered() -> Int {
    var n = 0
    #if os(macOS)
        n += Gamma().macOnlyCalled()
    #endif
    #if os(iOS)
        #if targetEnvironment(simulator)
            n += Delta().paint()
        #endif
    #endif
    _ = Epsilon()
    return n
}
