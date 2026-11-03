import Foundation

// `NSLocalizedString(bundle:)` does not exist in swift-corelibs-foundation.
#if canImport(Darwin)
    public enum DynamicKeys {
        public static func title(keyName: String) -> String {
            NSLocalizedString(keyName, bundle: .module, comment: "")
        }

        public static func mixedTitle(flag: Bool, keyName: String) -> String {
            NSLocalizedString(flag ? "dyn_mixed_known_key" : keyName, bundle: .module, comment: "")
        }
    }
#else
    public enum DynamicKeys {
        public static func title(keyName: String) -> String {
            keyName
        }

        public static func mixedTitle(flag _: Bool, keyName: String) -> String {
            keyName
        }
    }
#endif
