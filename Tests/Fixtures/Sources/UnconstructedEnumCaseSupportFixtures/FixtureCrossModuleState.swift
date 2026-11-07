public enum FixtureCrossModuleState {
    case idle
    case constructedElsewhere
    case onlyMatchedHere
}

public func fixtureCrossModuleMatch(_ state: FixtureCrossModuleState) -> Bool {
    switch state {
    case .constructedElsewhere: true
    case .onlyMatchedHere: true
    case .idle: false
    }
}

public func fixtureCrossModuleIdle() -> Bool {
    fixtureCrossModuleMatch(.idle)
}
