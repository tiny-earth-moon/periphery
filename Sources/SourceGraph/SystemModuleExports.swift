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
}
