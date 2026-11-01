/// System frameworks known to re-export other modules (`@_exported import`), which the index store does not record.
///
/// Every module a system module depends on in the index store is already treated as possibly exported by it; this
/// list covers the documented re-exports for stores whose system units lack dependencies.
enum SystemModuleExports {
    static let known: [String: Set<String>] = [
        "AppKit": ["Foundation"],
        "Cocoa": ["AppKit", "CoreData", "Foundation"],
        "Foundation": ["CoreFoundation", "Darwin", "Dispatch", "ObjectiveC"],
        "SwiftUI": ["SwiftUICore"],
        "UIKit": ["Foundation"],
    ]

    /// Modules every Swift file imports implicitly. A system module depending on them does not make their
    /// declarations a use of that module.
    static let implicitlyImported: Set<String> = ["Swift", "SwiftOnoneSupport", "_Concurrency", "_StringProcessing"]
}
