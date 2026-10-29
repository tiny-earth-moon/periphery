import Foundation

public enum LocalizationUsage {
    public static var message: String {
        NSLocalizedString("spm_used_key", bundle: .module, comment: "")
    }

    public static func ternaryMessage(first: Bool, second: Bool) -> String {
        String(localized: first ? "spm_ternary_first_key" : second ? "spm_ternary_second_key" : "spm_ternary_third_key", bundle: .module)
    }
}
