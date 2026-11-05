import Foundation

public class FixtureClass1700 {
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

    public func hydrate() {
        isHydrating = true
        defer { isHydrating = false }
        isLoading = true
        neverRead = true
        title = "title"
        subtitle = "subtitle"
    }
}
