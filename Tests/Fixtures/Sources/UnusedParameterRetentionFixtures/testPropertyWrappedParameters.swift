import Foundation

@propertyWrapper
struct Clamped {
    var wrappedValue: Int
    let range: ClosedRange<Int>

    init(wrappedValue: Int, _ range: ClosedRange<Int>) {
        self.wrappedValue = min(max(wrappedValue, range.lowerBound), range.upperBound)
        self.range = range
    }

    var projectedValue: ClosedRange<Int> { range }
}

public class WrappedParameterHost {
    public func viaProjection(@Clamped(0 ... 5) level: Int) -> String {
        "\($level)"
    }

    public func viaStorage(@Clamped(0 ... 5) level: Int) -> Int {
        _level.range.upperBound
    }

    public func viaValue(@Clamped(0 ... 5) level: Int) -> Int {
        level
    }

    public func unusedWrapped(@Clamped(0 ... 5) level: Int) -> Int { 1 }

    public func call() {
        _ = viaProjection(level: 3)
        _ = viaStorage(level: 3)
        _ = viaValue(level: 3)
        _ = unusedWrapped(level: 3)
    }
}
