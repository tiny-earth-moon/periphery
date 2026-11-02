import Foundation

enum FixtureAllCasesUsedEnum: CaseIterable {
    case first
    case second
}

enum FixtureAllCasesUsedCountEnum: CaseIterable {
    case first
    case second
}

enum FixtureAllCasesUsedInArgumentEnum: CaseIterable {
    case first
    case second
}

enum FixtureAllCasesNotUsedEnum: CaseIterable {
    case first
    case second
}

enum FixtureExplicitAllCasesEnum: CaseIterable {
    case first
    case second

    static var allCases: [FixtureExplicitAllCasesEnum] { [.first] }
}

enum FixtureNotCaseIterableEnum {
    case first
    case second
}

enum FixtureAllCasesOnlyUsedByUnusedCodeEnum: CaseIterable {
    case first
    case second
}

func fixtureUnusedAllCasesUser() {
    print(FixtureAllCasesOnlyUsedByUnusedCodeEnum.allCases)
}

enum FixtureOuterCaseIterableEnum: CaseIterable {
    case outer

    enum Inner: CaseIterable {
        case first
        case second
    }
}

func fixtureConsume(_ values: [some Any]) {
    print(values)
}

public func fixtureAllCasesUsageRoot() {
    for value in FixtureAllCasesUsedEnum.allCases {
        print(value)
    }

    print(FixtureAllCasesUsedCountEnum.allCases.count)
    fixtureConsume(FixtureAllCasesUsedInArgumentEnum.allCases)
    print(FixtureExplicitAllCasesEnum.allCases)
    _ = FixtureAllCasesNotUsedEnum.self
    _ = FixtureAllCasesOnlyUsedByUnusedCodeEnum.self
    print(FixtureOuterCaseIterableEnum.Inner.allCases)
    _ = FixtureNotCaseIterableEnum.self
}
