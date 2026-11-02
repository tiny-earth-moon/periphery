import Foundation

public struct InlineArrayReturnElement {
    init() {}
}

public struct InlineArrayParameterElement {
    init() {}
}

public struct InlineArrayVariableElement {
    init() {}
}

public struct InlineArrayInternalOnlyElement {
    init() {}
}

public struct PackReturnBox<Value> {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

public struct PackParameterBox<Value> {
    init(_ value: Value) {}
}

@available(macOS 26, iOS 26, *)
public func publicInlineArrayReturn() -> [2 of InlineArrayReturnElement] {
    [InlineArrayReturnElement(), InlineArrayReturnElement()]
}

@available(macOS 26, iOS 26, *)
public func publicInlineArrayParameter(_ elements: [2 of InlineArrayParameterElement]) {}

@available(macOS 26, iOS 26, *)
public var publicInlineArrayVariable: [2 of InlineArrayVariableElement] {
    [InlineArrayVariableElement(), InlineArrayVariableElement()]
}

public func publicPackReturn<each T>(_ values: repeat each T) -> (repeat PackReturnBox<each T>) {
    (repeat PackReturnBox(each values))
}

public func publicPackParameter<each T>(_ boxes: repeat PackParameterBox<each T>) {}

// periphery:ignore
@available(macOS 26, iOS 26, *)
func internalInlineArrayReturn() -> [2 of InlineArrayInternalOnlyElement] {
    [InlineArrayInternalOnlyElement(), InlineArrayInternalOnlyElement()]
}
