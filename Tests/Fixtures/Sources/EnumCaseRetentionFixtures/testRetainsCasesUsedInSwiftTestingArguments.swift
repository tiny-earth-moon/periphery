#if canImport(Testing)
import Testing

enum FixtureTestArgumentEnum: CaseIterable {
    case first
    case second
}

@Test(arguments: FixtureTestArgumentEnum.allCases)
func fixtureTestWithEnumArguments(_ value: FixtureTestArgumentEnum) {
    #expect(value == value)
}
#endif
