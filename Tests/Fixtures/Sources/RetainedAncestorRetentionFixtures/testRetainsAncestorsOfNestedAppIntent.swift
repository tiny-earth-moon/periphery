import AppIntents

enum IntentNamespace {
    struct NestedIntent: AppIntent {
        static let title: LocalizedStringResource = "Nested"

        func perform() async throws -> some IntentResult {
            .result()
        }
    }

    static let unusedConstant = 1
}

enum UnusedIntentNamespace {
    static let unusedConstant = 1
}
