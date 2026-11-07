protocol FixtureSelfDefaultable {
    static var initial: Self { get }
}

extension FixtureSelfDefaultable {
    static func reset() -> Self {
        Self.initial
    }
}

enum FixtureSelfDefaultableEnum: FixtureSelfDefaultable {
    case initial
    case unusedCase
}

public func fixtureSelfDefaultableRoot() {
    _ = FixtureSelfDefaultableEnum.reset()
}
