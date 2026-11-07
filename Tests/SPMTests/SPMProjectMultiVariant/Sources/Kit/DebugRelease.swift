struct Mode {
    let debugLabel = "d"
    let releaseLabel = "r"
    var label: String {
        #if DEBUG
            debugLabel
        #else
            releaseLabel
        #endif
    }
}

public func modeLabel() -> String {
    Mode().label
}
