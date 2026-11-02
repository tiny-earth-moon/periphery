import SwiftData

@available(macOS 14, *)
public enum FixtureMacroModelSchema: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [FixtureMacroModelSoleInitializer.self, FixtureMacroModelSecondInitializer.self]
    }

    @Model
    final class FixtureMacroModelSoleInitializer {
        var text: String

        init(text: String) {
            self.text = text
        }
    }

    @Model
    final class FixtureMacroModelSecondInitializer {
        var text: String

        init(text: String) {
            self.text = text
        }

        init(other: String) {
            text = other
        }
    }
}
