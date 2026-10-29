import AppIntents
import Foundation

public enum SPMAppIntentsNamespace {
    public enum Kind: String, AppEnum {
        case first

        public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "mac_ai_type_name_key")
        public static let caseDisplayRepresentations: [Kind: DisplayRepresentation] = [
            .first: DisplayRepresentation(title: "mac_ai_case_title_key", subtitle: "mac_ai_case_subtitle_key"),
        ]
    }

    public struct SummaryIntent: AppIntent {
        public static let title: LocalizedStringResource = "mac_ai_intent_title_key"
        public static let description = IntentDescription("mac_ai_intent_description_key")

        @Parameter(title: "mac_ai_param_name_key")
        public var name: String

        @Parameter(title: "mac_ai_param_flag_key")
        public var flag: Bool

        public init() {}

        public static var parameterSummary: some ParameterSummary {
            When(\.$flag, .equalTo, true) {
                Summary("mac_ai_summary_when_key") {
                    \.$name
                    \.$flag
                }
            } otherwise: {
                Summary("mac_ai_summary_otherwise_key") {
                    \.$name
                }
            }
        }

        public func perform() async throws -> some IntentResult & ProvidesDialog {
            .result(dialog: "mac_ai_dialog_key")
        }
    }

    public struct Shortcuts: AppShortcutsProvider {
        public static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: SummaryIntent(),
                phrases: ["mac_ai_phrase_key \(.applicationName)"],
                shortTitle: "mac_ai_shortcut_title_key",
                systemImageName: "star"
            )
        }
    }
}
