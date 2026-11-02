import Foundation

@propertyWrapper
struct Bounded {
    var wrappedValue: Int
    let range: ClosedRange<Int>

    init(wrappedValue: Int, _ range: ClosedRange<Int>) {
        self.wrappedValue = min(max(wrappedValue, range.lowerBound), range.upperBound)
        self.range = range
    }

    init(other: Int) {
        wrappedValue = other
        range = 0 ... other
    }

    var projectedValue: ClosedRange<Int> { range }
}

public class WrapperInitializerHost {
    public func apply(@Bounded(0 ... 5) level: Int) -> String {
        "\($level)"
    }
}
