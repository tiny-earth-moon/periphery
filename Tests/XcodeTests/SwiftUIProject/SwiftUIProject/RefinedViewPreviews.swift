import SwiftUI

protocol RefinedScreen: View {}

struct LiveRefinedScreen: RefinedScreen {
    var body: some View {
        Text("Live")
    }
}

struct LiveRefinedScreen_LibraryContentProvider: LibraryContentProvider {
    var views: [LibraryItem] {
        LibraryItem(LiveRefinedScreen())
    }
}

enum LiveRefinedPreviewData {
    static let title = "Sample"
}

#Preview("LiveRefined") {
    VStack {
        LiveRefinedScreen()
        Text(LiveRefinedPreviewData.title)
    }
}

struct DeadRefinedScreen: RefinedScreen {
    var body: some View {
        Text("Dead")
    }
}

enum DeadRefinedPreviewData {
    static let title = "Dead"
}

#Preview("DeadRefined") {
    VStack {
        DeadRefinedScreen()
        Text(DeadRefinedPreviewData.title)
    }
}
