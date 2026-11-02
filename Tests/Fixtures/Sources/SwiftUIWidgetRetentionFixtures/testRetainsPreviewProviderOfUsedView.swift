import SwiftUI

public struct ProvidedPreviewRoot: View {
    public init() {}

    public var body: some View {
        UsedProvidedPreviewView(title: "Item")
    }
}

struct UsedProvidedPreviewView: View {
    let title: String

    var body: some View {
        Text(title)
    }
}

enum ProvidedPreviewSampleData {
    static let title = "Sample"
    static let unreferencedTitle = "Unreferenced"
}

struct UsedProvidedPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        UsedProvidedPreviewView(title: ProvidedPreviewSampleData.title)
    }
}

struct DeadProvidedPreviewView: View {
    var body: some View {
        Text("Dead")
    }
}

enum DeadProvidedPreviewSampleData {
    static let title = "Dead"
}

struct DeadProvidedPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DeadProvidedPreviewView()
            Text(DeadProvidedPreviewSampleData.title)
        }
    }
}
