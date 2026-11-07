import Foundation

@propertyWrapper
struct FixtureTrimmed {
    var wrappedValue: String

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue.trimmingCharacters(in: .whitespaces)
    }

    init(projectedValue: FixtureTrimmed) {
        self = projectedValue
    }

    init(unused: Int) {
        wrappedValue = String(unused)
    }

    var projectedValue: FixtureTrimmed { self }
}

public class FixtureTrimmedHost {
    func viaProjection(@FixtureTrimmed name: String) -> Int {
        $name.wrappedValue.count
    }

    func viaStorage(@FixtureTrimmed name: String) -> String {
        _name.wrappedValue
    }

    func forwardsProjection(@FixtureTrimmed name: String) -> Int {
        viaProjection($name: $name)
    }

    public func call() {
        _ = viaStorage(name: " a ")
        _ = forwardsProjection(name: " b ")
    }
}
