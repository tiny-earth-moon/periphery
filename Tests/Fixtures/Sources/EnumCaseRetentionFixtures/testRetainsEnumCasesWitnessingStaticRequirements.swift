protocol FixtureDefaultable {
    static var fallback: Self { get }
}

enum FixtureThemeEnum: FixtureDefaultable {
    case fallback
    case dark
}

protocol FixtureFactory {
    static func make(_ value: Int) -> Self
}

enum FixtureBoxEnum: FixtureFactory {
    case make(Int)
    case other
}

protocol FixtureUnusedRequirement {
    static var fallback: Self { get }
}

enum FixtureUnusedRequirementEnum: FixtureUnusedRequirement {
    case fallback
    case dark
}

func fixtureMakeDefault<T: FixtureDefaultable>(_: T.Type) -> T {
    T.fallback
}

func fixtureBuild<T: FixtureFactory>(_: T.Type) -> T {
    T.make(1)
}

public func fixtureStaticWitnessUsageRoot() {
    _ = fixtureMakeDefault(FixtureThemeEnum.self)
    _ = fixtureBuild(FixtureBoxEnum.self)
    _ = FixtureThemeEnum.dark
    _ = FixtureBoxEnum.other
    _ = FixtureUnusedRequirementEnum.dark
}
