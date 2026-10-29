#if os(macOS)
    import Configuration
    @testable import TestShared
    import XCTest

    final class SPMProjectMacOSAppIntentsLocalizedStringTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            let configuration = Configuration()
            configuration.buildFilenameMatchers()
            build(projectPath: SPMProjectMacOSPath)
            index(configuration: configuration)
        }

        func testRetainsParameterSummaryKeys() {
            assertReferenced(.localizedString("mac_ai_summary_when_key"))
            assertReferenced(.localizedString("mac_ai_summary_otherwise_key"))
        }

        func testRetainsOtherAppIntentsKeys() {
            assertReferenced(.localizedString("mac_ai_type_name_key"))
            assertReferenced(.localizedString("mac_ai_case_title_key"))
            assertReferenced(.localizedString("mac_ai_case_subtitle_key"))
            assertReferenced(.localizedString("mac_ai_intent_title_key"))
            assertReferenced(.localizedString("mac_ai_intent_description_key"))
            assertReferenced(.localizedString("mac_ai_param_name_key"))
            assertReferenced(.localizedString("mac_ai_param_flag_key"))
            assertReferenced(.localizedString("mac_ai_dialog_key"))
            assertReferenced(.localizedString("mac_ai_shortcut_title_key"))
        }

        func testDoesNotRetainUnusedAppIntentsKeys() {
            assertNotReferenced(.localizedString("mac_ai_unused_key"))
        }
    }
#endif
