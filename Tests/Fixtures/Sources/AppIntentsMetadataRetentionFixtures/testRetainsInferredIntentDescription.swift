import AppIntents

struct InferredLetIntent: AppIntent {
    static let title: LocalizedStringResource = "Inferred Let"
    static let description = IntentDescription("Describes the intent")
    static let unusedHelper = 1

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct InferredVarIntent: AppIntent {
    static let title: LocalizedStringResource = "Inferred Var"
    static var description = IntentDescription("Describes the intent")

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OptionalDescriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Optional"
    static let description: IntentDescription? = IntentDescription("Describes the intent")

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct DescribedWidget {
    static let description = "Not an intent"
}

public func retainDescribedWidget() {
    _ = DescribedWidget.self
}
