#if os(macOS)
    import Configuration
    @testable import TestShared
    import XCTest

    final class SPMProjectMacOSLocalizedStringLiteralMatchTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            let configuration = Configuration()
            configuration.localizedStringKeyLiteralMatch = true
            configuration.buildFilenameMatchers()
            build(projectPath: SPMProjectMacOSPath)
            index(configuration: configuration)
        }

        func testRetainsKeysEqualToAnyStringLiteral() {
            assertReferenced(.localizedString("mac_literal_switch_first_key"))
            assertReferenced(.localizedString("mac_literal_switch_second_key"))
            assertReferenced(.localizedString("mac_literal_field_key"))
            assertReferenced(.localizedString("mac_literal_tuple_key"))
        }

        func testDoesNotRetainKeysWithoutMatchingLiteral() {
            assertNotReferenced(.localizedString("mac_literal_unused_key"))
            assertNotReferenced(.localizedString("mac_unused_key"))
        }
    }

    final class SPMProjectMacOSLocalizedStringLiteralMatchDisabledTest: SPMSourceGraphTestCase {
        override static func setUp() {
            super.setUp()

            let configuration = Configuration()
            configuration.buildFilenameMatchers()
            build(projectPath: SPMProjectMacOSPath)
            index(configuration: configuration)
        }

        func testDoesNotRetainKeysPassedAsStrings() {
            assertNotReferenced(.localizedString("mac_literal_switch_first_key"))
            assertNotReferenced(.localizedString("mac_literal_switch_second_key"))
            assertNotReferenced(.localizedString("mac_literal_field_key"))
            assertNotReferenced(.localizedString("mac_literal_tuple_key"))
            assertNotReferenced(.localizedString("mac_literal_unused_key"))
        }
    }
#endif
