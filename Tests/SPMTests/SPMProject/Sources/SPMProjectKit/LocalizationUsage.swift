import Foundation

// `NSLocalizedString(bundle:)` and `String(localized:bundle:)` do not exist in swift-corelibs-foundation.
#if canImport(Darwin)
    public enum LocalizationUsage {
        public static var message: String {
            NSLocalizedString("spm_used_key", bundle: .module, comment: "")
        }

        public static func ternaryMessage(first: Bool, second: Bool) -> String {
            String(localized: first ? "spm_ternary_first_key" : second ? "spm_ternary_second_key" : "spm_ternary_third_key", bundle: .module)
        }

        public static func runtimeMessages(suffix: String) -> [String] {
            [
                NSLocalizedString("spm_prefix." + suffix, bundle: .module, comment: ""),
                Bundle.module.localizedString(forKey: "spm_interpolated.\(suffix)", value: nil, table: nil),
                NSLocalizedString("spm_main_bundle.\(suffix)", comment: ""),
            ]
        }
    }
#else
    public enum LocalizationUsage {
        public static var message: String {
            ""
        }

        public static func ternaryMessage(first _: Bool, second _: Bool) -> String {
            ""
        }

        public static func runtimeMessages(suffix _: String) -> [String] {
            []
        }
    }
#endif
