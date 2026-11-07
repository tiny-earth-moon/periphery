protocol FixtureFallbackProviding {
    static var fallback: Self { get }
}

protocol FixtureMaking {
    static func make(_ value: Int) -> Self
}

enum FixtureRequirementState: FixtureFallbackProviding, FixtureMaking {
    case idle
    case fallback
    case make(Int)
    case onlyMatched
}

enum FixtureExternalProtocolState: CustomReflectable {
    case idle
    case onlyMatched

    var customMirror: Mirror {
        Mirror(reflecting: 0)
    }
}

func fixtureMakeFallback<T: FixtureFallbackProviding>(_: T.Type) -> T {
    T.fallback
}

func fixtureMake<T: FixtureMaking>(_: T.Type) -> T {
    T.make(1)
}

public func fixtureRequirementMatch() -> Int {
    let state = FixtureRequirementState.idle
    switch state {
    case .fallback: return 1
    case .make: return 2
    case .onlyMatched: return 3
    case .idle: break
    }
    if case .onlyMatched = FixtureExternalProtocolState.idle { return 4 }
    return [fixtureMakeFallback(FixtureRequirementState.self), fixtureMake(FixtureRequirementState.self)].count
}
