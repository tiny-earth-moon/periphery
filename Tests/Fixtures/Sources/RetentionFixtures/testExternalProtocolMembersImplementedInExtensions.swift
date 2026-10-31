import Foundation

struct FixtureStruct1110 {
    let id: Int
}

extension FixtureStruct1110: Identifiable {}

extension FixtureStruct1110: CustomStringConvertible {
    var description: String { "" }
}

extension FixtureStruct1110: Comparable {
    static func < (lhs: FixtureStruct1110, rhs: FixtureStruct1110) -> Bool { lhs.id < rhs.id }
}

extension FixtureStruct1110: Hashable {
    func hash(into hasher: inout Hasher) {}
}

final class FixtureClass1110: NSObject {}

extension FixtureClass1110: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any { self }
}

extension FixtureClass1110: NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    func encode(with coder: NSCoder) {}
    convenience init?(coder: NSCoder) { self.init() }
}

public class FixtureClass1110Retainer {
    public func retain() {
        _ = FixtureStruct1110(id: 1)
        _ = FixtureClass1110()
    }
}
