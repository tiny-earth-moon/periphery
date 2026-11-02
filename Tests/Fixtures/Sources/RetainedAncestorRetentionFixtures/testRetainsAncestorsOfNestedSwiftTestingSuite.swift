#if canImport(Testing)
import Testing

enum SuiteNamespace {
    @Suite struct NestedSuite {
        @Test func nestedTest() {}
    }

    enum Inner {
        struct PlainContainer {
            @Test func containedTest() {}
        }
    }
}

enum UnusedSuiteNamespace {
    static let unusedConstant = 1
}
#endif
