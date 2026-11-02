import Foundation

// Each form is written once on a single line and once on several lines.

public struct OneLineCasePayload {}
public struct MultiLineCasePayload {}
public enum OneLineCaseHolder { case value(OneLineCasePayload) }
public enum MultiLineCaseHolder {
    case value(MultiLineCasePayload)
}

public struct OneLineLabeledCasePayload {}
public struct MultiLineLabeledCasePayload {}
public enum OneLineLabeledCaseHolder { case value(first: OneLineLabeledCasePayload, second: Int); case other }
public enum MultiLineLabeledCaseHolder {
    case value(first: MultiLineLabeledCasePayload, second: Int)
    case other
}

public struct OneLineSubscriptResult {}
public struct MultiLineSubscriptResult {}
public struct OneLineSubscriptHolder { public init() {}; public subscript(index: Int) -> OneLineSubscriptResult? { nil } }
public struct MultiLineSubscriptHolder {
    public init() {}

    public subscript(index: Int) -> MultiLineSubscriptResult? { nil }
}

public struct OneLineTypealiasTarget {}
public struct MultiLineTypealiasTarget {}
public struct OneLineTypealiasHolder { public typealias Handler = (OneLineTypealiasTarget) -> Void; public init() {} }
public struct MultiLineTypealiasHolder {
    public typealias Handler = (MultiLineTypealiasTarget) -> Void

    public init() {}
}

public struct OneLineControlType {}
public struct OneLineControlHolder { public init() { _ = OneLineControlType() }; func useInternally(_ value: OneLineControlType) {} }
