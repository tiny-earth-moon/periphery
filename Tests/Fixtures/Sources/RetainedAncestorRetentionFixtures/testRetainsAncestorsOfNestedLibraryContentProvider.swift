import SwiftUI

enum ProviderNamespace {
    struct NestedLibraryProvider: LibraryContentProvider {
        var views: [LibraryItem] { [] }
    }
}

enum UnusedProviderNamespace {
    static let unusedConstant = 1
}
