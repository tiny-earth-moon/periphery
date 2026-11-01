import Configuration
@testable import TestShared
import XCTest

final class SPMProjectTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: SPMProjectPath)
        index(configuration: Configuration())
    }

    func testMainEntryFile() {
        assertReferenced(.functionFree("main()"))
    }

    func testCrossModuleReference() {
        assertReferenced(.class("PublicCrossModuleReferenced"))
        assertNotReferenced(.class("PublicCrossModuleNotReferenced"))
    }

    func testMacroImport() {
        assertReferenced(.module("SPMProjectKit"))
    }

    func testLocalizedStrings() {
        assertReferenced(.localizedString("spm_used_key"))
        assertReferenced(.localizedString("spm_ternary_first_key"))
        assertReferenced(.localizedString("spm_ternary_second_key"))
        assertReferenced(.localizedString("spm_ternary_third_key"))
        assertNotReferenced(.localizedString("spm_unused_key"))
    }

    func testRetainsKeysOfRuntimeLookupsByPrefixAndBundle() {
        // Literal prefix of a `+` concatenation or of an interpolation passed to a `String` key parameter.
        assertReferenced(.localizedString("spm_prefix.alpha"))
        assertReferenced(.localizedString("spm_interpolated.beta"))
        // Main bundle lookup: matched in every catalog.
        assertReferenced(.localizedString("spm_main_bundle.gamma"))
        // The literal branch of a ternary mixing a literal and a runtime key is used.
        assertReferenced(.localizedString("dyn_mixed_known_key"))
    }

    func testUnprefixedRuntimeLookup_doesNotRetainEveryKeyByDefault() {
        // `NSLocalizedString(keyName, bundle: .module)` may look up any key: nothing is retained without
        // `retain_runtime_localized_keys`.
        assertNotReferenced(.localizedString("dyn_runtime_key"))
        assertNotReferenced(.localizedString("spm_unused_key"))
    }
}

final class SPMProjectRetainRuntimeLocalizedKeysTest: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        let configuration = Configuration()
        configuration.retainRuntimeLocalizedKeys = true
        build(projectPath: SPMProjectPath)
        index(configuration: configuration)
    }

    func testUnprefixedRuntimeLookup_retainsEveryKeyOfTheModuleCatalog() {
        // With `bundle: .module`, every key of the calling module's catalog is retained, other modules' catalogs are
        // unaffected (`spm_unused_key`).
        assertReferenced(.localizedString("dyn_runtime_key"))
        assertReferenced(.localizedString("dyn_mixed_known_key"))
        assertNotReferenced(.localizedString("spm_unused_key"))
    }
}
