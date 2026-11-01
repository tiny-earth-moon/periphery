import Foundation
import SwiftUI

enum LocalizationUsage {
    static func useStrings() {
        _ = NSLocalizedString("swiftui_used_key", comment: "")
        _ = runtimeString("swiftui_runtime_argument")
    }

    /// A central helper looking keys up at runtime, without a literal prefix: it must not retain every key.
    static func runtimeString(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func textView() -> some View {
        Text("swiftui_text_key")
    }

    @available(iOS 16, *)
    static func generatedSymbols() -> [String] {
        // Xcode 26+ String Catalog symbols (STRING_CATALOG_GENERATE_SYMBOLS).
        [String(localized: .generatedUsed), String(localized: .generatedCount(3))]
    }
}

