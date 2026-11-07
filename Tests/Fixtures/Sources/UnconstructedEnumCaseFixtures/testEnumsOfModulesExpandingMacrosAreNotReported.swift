enum FixtureMacroModuleState {
    case idle
    case onlyMatched
}

public func fixtureMacroModuleMatch() -> Bool {
    if case .onlyMatched = FixtureMacroModuleState.idle { return true }
    return false
}

#if canImport(Testing)
    import Testing

    extension Tag {
        @Tag static var fixtureMacroModuleTag: Self
    }
#endif
