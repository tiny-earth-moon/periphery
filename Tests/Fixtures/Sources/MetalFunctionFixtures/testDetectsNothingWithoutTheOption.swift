import Metal

public final class FixtureClass1602 {
    public func makeFunction(library: MTLLibrary) -> MTLFunction? {
        library.makeFunction(name: "fixtureMissingFunction")
    }
}
