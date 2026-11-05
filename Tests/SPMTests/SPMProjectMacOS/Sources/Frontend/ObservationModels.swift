import Observation
import SwiftData
import SwiftUI

@available(macOS 14, *)
@Observable final class ObservedStore {
    var readValue: Int = 0
    var neverTouched: Int = 0
    var assignedOnly: Int = 0
    var assignedFromOutside: Int = 0
    var initializedOnly: Int
    var boundValue: Bool = false
    @ObservationIgnored var ignoredNeverTouched: Int = 0

    init() {
        initializedOnly = 1
    }

    func bump() {
        assignedOnly = 1
        print(readValue)
    }
}

@available(macOS 14, *)
final class PlainStore {
    var readValue: Int = 0
    var neverTouched: Int = 0
    var assignedOnly: Int = 0
    var initializedOnly: Int

    init() {
        initializedOnly = 1
    }

    func bump() {
        assignedOnly = 1
        print(readValue)
    }
}

@available(macOS 14, *)
@Observable final class HydratingStore {
    private var isHydrating = false
    private var isLoading: Bool = false
    private var neverRead: Bool = false

    var title: String = "" {
        didSet {
            guard !isHydrating else { return }

            print(title)
        }
    }

    var subtitle: String = "" {
        willSet {
            guard !isLoading else { return }

            print(newValue)
        }
    }

    func hydrate() {
        isHydrating = true
        defer { isHydrating = false }
        isLoading = true
        neverRead = true
        title = "title"
        subtitle = "subtitle"
    }
}

@available(macOS 14, *)
struct ObservedStoreView: View {
    @Bindable var store: ObservedStore

    var body: some View {
        Toggle("Bound", isOn: $store.boundValue)
    }
}

@available(macOS 14, *)
@Model final class PersistedItem {
    var title: String = ""
    var neverTouched: Int = 0

    init() {}
}

@available(macOS 14, *)
func retainObservationModels() {
    let store = ObservedStore()
    store.bump()
    store.assignedFromOutside = 1
    PlainStore().bump()
    HydratingStore().hydrate()
    _ = ObservedStoreView(store: store).body
    _ = PersistedItem()
}
