import AppIntents

protocol BaseIntent: AppIntent {}

extension BaseIntent {
    static var openAppWhenRun: Bool { true }
}

struct RefinedIntent: BaseIntent {
    static let title: LocalizedStringResource = "Refined"

    func perform() async throws -> some IntentResult {
        .result()
    }
}

protocol DeepBaseIntent: BaseIntent {}

struct DeeplyRefinedIntent: DeepBaseIntent {
    static let title: LocalizedStringResource = "Deeply Refined"

    func perform() async throws -> some IntentResult {
        .result()
    }
}

protocol PlainBase: Sendable {}

struct PlainConforming: PlainBase {}
