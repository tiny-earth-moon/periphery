import Metal

public final class FixtureClass1600 {
    public func makeFunctions(library: MTLLibrary) throws {
        _ = library.makeFunction(name: "fixtureUsedKernel")
        _ = try library.makeFunction(name: "fixtureSpecializedVertex", constantValues: MTLFunctionConstantValues())
        _ = library.makeFunction(name: "fixtureMissingFunction")
        _ = library.makeFunction(name: "fixtureConditionalKernel")

        let descriptor = MTLFunctionDescriptor()
        descriptor.name = "fixtureDescriptorVisible"

        // A `name` property that is not the one of a function descriptor names no Metal function.
        var item = FixtureItem1600()
        item.name = "fixtureUnusedFragment"
        _ = item
    }
}

struct FixtureItem1600 {
    var name = ""
}
