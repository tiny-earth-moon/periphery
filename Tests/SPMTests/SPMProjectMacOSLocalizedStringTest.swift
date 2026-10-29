#if os(macOS)
    import Configuration
    @testable import TestShared
    import XCTest

    final class SPMProjectMacOSLocalizedStringTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            let configuration = Configuration()
            configuration.buildFilenameMatchers()
            build(projectPath: SPMProjectMacOSPath)
            index(configuration: configuration)
        }

        func testRetainsKeysPassedToLocalizedParameters() {
            assertReferenced(.localizedString("mac_button_key"))
            assertReferenced(.localizedString("mac_label_key"))
            assertReferenced(.localizedString("mac_toggle_key"))
            assertReferenced(.localizedString("mac_section_key"))
            assertReferenced(.localizedString("mac_navigation_title_key"))
            assertReferenced(.localizedString("mac_text_key"))
            assertReferenced(.localizedString("mac_ternary_true_key"))
            assertReferenced(.localizedString("mac_ternary_false_key"))
            assertReferenced(.localizedString("mac_custom_init_key"))
            assertReferenced(.localizedString("mac_resource_param_key"))
            assertReferenced(.localizedString("mac_localization_value_param_key"))
            assertReferenced(.localizedString("mac_variadic_key"))
        }

        func testRetainsKeysFromLocalizedDeclarationTypes() {
            assertReferenced(.localizedString("mac_annotated_property_key"))
            assertReferenced(.localizedString("mac_returned_resource_key"))
            assertReferenced(.localizedString("mac_default_value_key"))
        }

        func testRetainsInterpolatedKeys() {
            assertReferenced(.localizedString("mac_interpolated_string_key %@"))
            assertReferenced(.localizedString("mac_interpolated_int_key %lld"))
            assertReferenced(.localizedString("mac_interpolated_double_key %lf"))
            assertNotReferenced(.localizedString("mac_interpolated_unused_key %@"))
        }

        func testRetainsReturnedKeys() {
            assertReferenced(.localizedString("mac_switch_first_key"))
            assertReferenced(.localizedString("mac_switch_second_key"))
            assertReferenced(.localizedString("mac_ternary_return_key"))
            assertReferenced(.localizedString("mac_ternary_return_count_key %lld"))
        }

        func testRetainsTypedCollectionAndStructInitKeys() {
            assertReferenced(.localizedString("mac_typed_array_key"))
            assertReferenced(.localizedString("mac_typed_dictionary_key"))
            assertReferenced(.localizedString("mac_typed_tuple_key"))
            assertReferenced(.localizedString("mac_struct_init_key"))
            assertReferenced(.localizedString("mac_struct_trailing_key"))
            assertNotReferenced(.localizedString("mac_typed_tuple_symbol_key"))
            assertNotReferenced(.localizedString("mac_struct_image_key"))
        }

        func testDoesNotRetainKeysPassedToStringParameters() {
            assertNotReferenced(.localizedString("mac_plain_string_param_key"))
            assertNotReferenced(.localizedString("mac_label_system_image_key"))
            assertNotReferenced(.localizedString("mac_unused_key"))
            assertNotReferenced(.localizedString("mac_dynamic.alpha"))
        }

        func testExcludesInfoPlistAndAppShortcutsCatalogsByDefault() {
            assertNotIndexed(.localizedString("NSCameraUsageDescription"))
            assertNotIndexed(.localizedString("mac_shortcut_phrase"))
        }
    }

    final class SPMProjectMacOSLocalizedStringKeyPatternsTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            let configuration = Configuration()
            configuration.localizedStringKeyPatterns = ["mac_dynamic.*"]
            configuration.buildFilenameMatchers()
            build(projectPath: SPMProjectMacOSPath)
            index(configuration: configuration)
        }

        func testRetainsKeysMatchingDynamicPatterns() {
            assertReferenced(.localizedString("mac_dynamic.alpha"))
            assertReferenced(.localizedString("mac_dynamic.beta"))
            assertNotReferenced(.localizedString("mac_unused_key"))
        }
    }

    final class SPMProjectMacOSLocalizedStringCatalogExcludeTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            let configuration = Configuration()
            configuration.localizedStringCatalogExclude = ["**/Localizable.xcstrings"]
            configuration.buildFilenameMatchers()
            build(projectPath: SPMProjectMacOSPath)
            index(configuration: configuration)
        }

        func testExcludesConfiguredCatalogs() {
            assertNotIndexed(.localizedString("mac_unused_key"))
            assertNotIndexed(.localizedString("mac_button_key"))
            assertNotReferenced(.localizedString("NSCameraUsageDescription"))
            assertNotReferenced(.localizedString("mac_shortcut_phrase"))
        }
    }
#endif
