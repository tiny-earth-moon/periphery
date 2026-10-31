import AppIntents

struct ExtensionIntent {}

extension ExtensionIntent: AppIntent {
    static var title: LocalizedStringResource { "Extension Intent" }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ExtensionEntity {
    var id: String
}

extension ExtensionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Extension Entity" }
    static var defaultQuery: ExtensionEntityQuery { ExtensionEntityQuery() }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct ExtensionEntityQuery {}

extension ExtensionEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ExtensionEntity] {
        []
    }

    func suggestedEntities() async throws -> [ExtensionEntity] {
        []
    }
}
