import Foundation

public enum DynamicKeys {
    public static func title(keyName: String) -> String {
        NSLocalizedString(keyName, bundle: .module, comment: "")
    }

    public static func mixedTitle(flag: Bool, keyName: String) -> String {
        NSLocalizedString(flag ? "dyn_mixed_known_key" : keyName, bundle: .module, comment: "")
    }
}
