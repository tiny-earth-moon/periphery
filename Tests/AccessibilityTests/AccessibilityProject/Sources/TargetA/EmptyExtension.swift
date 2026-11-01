public protocol EmptyExtensionProtocol {}

public struct EmptyExtensionPlain {}
public struct EmptyExtensionCommentOnly {}
public struct EmptyExtensionConformance {}
public struct EmptyExtensionMember {}
public struct EmptyExtensionConditionalMember {}
public struct EmptyExtensionConditionalEmpty {}
public struct EmptyExtensionIgnored {}
public struct EmptyExtensionAvailability {}
public struct EmptyExtensionGeneric<T> {}

extension EmptyExtensionPlain {}

extension EmptyExtensionCommentOnly {
    // A comment is not a member.
    /* Neither is a block comment. */
}

extension EmptyExtensionConformance: EmptyExtensionProtocol {}

extension EmptyExtensionMember {
    func emptyExtensionMemberFunction() {}
}

extension EmptyExtensionConditionalMember {
    #if DEBUG
        func emptyExtensionConditionalMemberFunction() {}
    #endif
}

extension EmptyExtensionConditionalEmpty {
    #if DEBUG
    #else
    #endif
}

// periphery:ignore
extension EmptyExtensionIgnored {}

@available(macOS 10.15, *)
extension EmptyExtensionAvailability {}

extension EmptyExtensionGeneric where T: Equatable {}
