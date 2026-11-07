/// System frameworks known to re-export other modules (`@_exported import`), which the index store does not record.
///
/// Every module a system module depends on in the index store is already treated as possibly exported by it; this
/// list covers the documented re-exports for stores whose system units lack dependencies.
enum SystemModuleExports {
    /// The documented re-exports of the Apple SDK frameworks.
    static let appleSDK: [String: Set<String>] = [
        "AppKit": ["Foundation"],
        "Cocoa": ["AppKit", "CoreData", "Foundation"],
        "Foundation": ["CoreFoundation", "Darwin", "Dispatch", "ObjectiveC"],
        "SwiftUI": ["SwiftUICore"],
        "UIKit": ["Foundation"],
    ]

    /// Modules every Swift file imports implicitly. A system module depending on them does not make their
    /// declarations a use of that module.
    static let implicitlyImported: Set<String> = ["Swift", "SwiftOnoneSupport", "_Concurrency", "_StringProcessing"]

    /// The known re-exports for system units built for the given target triples.
    ///
    /// The Apple SDK re-exports do not apply when every system unit with a known target is built for another
    /// platform: on Linux, `Foundation` re-exports neither `Darwin` nor `ObjectiveC`, which do not exist there, and
    /// assuming it does would make `Foundation` look like it exports modules missing from the index store.
    static func known(forTargets targets: Set<String>) -> [String: Set<String>] {
        let knownTargets = targets.filter { !$0.isEmpty }

        if !knownTargets.isEmpty, !knownTargets.contains(where: isAppleTarget) {
            return [:]
        }

        return appleSDK
    }

    private static func isAppleTarget(_ target: String) -> Bool {
        target.contains("-apple-")
    }
}
