struct FixtureUncompiledChainHelper {
    struct Nested {
        func uncompiledChainRender() {}
    }

    func uncompiledChainPrepare() {}
}

struct FixtureUncompiledChainActive {
    func uncompiledChainCompiled() {}
}

struct FixtureUncompiledChainDecoy {
    func uncompiledChainCompiled() {}
}

public class FixtureUncompiledChainUser {
    private func onlyOnTVOS() {}
    private func onlyInElse() {}

    public func entry() {
        #if os(iOS)
        FixtureUncompiledChainHelper.Nested().uncompiledChainRender()
        #elseif os(macOS) || os(Linux)
        FixtureUncompiledChainActive().uncompiledChainCompiled()
        #elseif os(tvOS)
        onlyOnTVOS()
        FixtureUncompiledChainHelper().uncompiledChainPrepare()
        #else
        onlyInElse()
        #endif

        _ = FixtureUncompiledChainDecoy()
    }
}
