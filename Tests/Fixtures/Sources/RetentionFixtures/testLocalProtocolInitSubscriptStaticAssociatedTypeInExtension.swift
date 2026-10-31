import Foundation

protocol FixtureProtocol1111 {
    associatedtype Output
    init(value: Int)
    subscript(index: Int) -> Int { get }
    static var defaultValue: Self { get }
    static func make() -> Self
    func produce() -> Output
}

struct FixtureStruct1111 {
    var value: Int
}

extension FixtureStruct1111: FixtureProtocol1111 {
    typealias Output = String
    subscript(index: Int) -> Int { value + index }
    static var defaultValue: FixtureStruct1111 { .init(value: 0) }
    static func make() -> FixtureStruct1111 { .init(value: 1) }
    func produce() -> String { "" }
}

func fixture1111Use<T: FixtureProtocol1111>(_ type: T.Type) -> T {
    _ = T.defaultValue
    _ = T.make()
    return T(value: 1)
}

public class FixtureClass1111Retainer {
    public func retain() {
        _ = fixture1111Use(FixtureStruct1111.self)
    }
}
