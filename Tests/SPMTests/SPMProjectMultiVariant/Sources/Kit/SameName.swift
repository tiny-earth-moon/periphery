struct Alpha {
    func draw() -> Int {
        1
    }
}

struct Beta {
    func draw() -> Int {
        2
    }
}

public func sameName() -> Int {
    var n = 0
    #if os(iOS)
        n += Alpha().draw()
    #endif
    _ = Beta()
    return n
}
