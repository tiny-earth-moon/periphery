import SwiftUI
import WidgetKit

@available(macOS 14.0, *)
struct PreviewedWidgetEntry: TimelineEntry {
    let date: Date
}

@available(macOS 14.0, *)
struct PreviewedWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> PreviewedWidgetEntry {
        PreviewedWidgetEntry(date: .distantPast)
    }

    func getSnapshot(in _: Context, completion: @escaping (PreviewedWidgetEntry) -> Void) {
        completion(PreviewedWidgetEntry(date: .distantPast))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PreviewedWidgetEntry>) -> Void) {
        completion(Timeline(entries: [PreviewedWidgetEntry(date: .distantPast)], policy: .never))
    }
}

@available(macOS 14.0, *)
struct PreviewedWidgetView: View {
    let entry: PreviewedWidgetEntry

    var body: some View {
        Text(entry.date.description)
    }
}

@available(macOS 14.0, *)
struct UsedPreviewedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsedPreviewedWidget", provider: PreviewedWidgetProvider()) { entry in
            PreviewedWidgetView(entry: entry)
        }
    }
}

@available(macOS 14.0, *)
public struct PreviewedWidgetBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        UsedPreviewedWidget()
    }
}

@available(macOS 14.0, *)
extension PreviewedWidgetEntry {
    static let previewOnlySample = PreviewedWidgetEntry(date: .distantFuture)
    static let unreferencedSample = PreviewedWidgetEntry(date: .now)
}

@available(macOS 14.0, *)
#Preview(as: .systemSmall) {
    UsedPreviewedWidget()
} timeline: {
    PreviewedWidgetEntry.previewOnlySample
}

@available(macOS 14.0, *)
struct DeadPreviewedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeadPreviewedWidget", provider: PreviewedWidgetProvider()) { entry in
            PreviewedWidgetView(entry: entry)
        }
    }
}

@available(macOS 14.0, *)
extension PreviewedWidgetEntry {
    static let deadPreviewSample = PreviewedWidgetEntry(date: .distantPast)
}

@available(macOS 14.0, *)
#Preview(as: .systemSmall) {
    DeadPreviewedWidget()
} timeline: {
    PreviewedWidgetEntry.deadPreviewSample
}
