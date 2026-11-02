import SwiftUI

protocol BaseLibraryProvider: LibraryContentProvider {}

struct RefinedLibraryProvider: BaseLibraryProvider {
    var views: [LibraryItem] { [] }
}

protocol PlainLibraryBase: Sendable {}

struct PlainLibraryConforming: PlainLibraryBase {}
