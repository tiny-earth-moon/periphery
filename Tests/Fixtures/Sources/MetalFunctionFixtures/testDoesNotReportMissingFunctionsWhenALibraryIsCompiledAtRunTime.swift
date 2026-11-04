import Metal

public final class FixtureClass1603 {
    public func makeKernel(device: MTLDevice) throws -> MTLFunction? {
        let library = try device.makeLibrary(source: "kernel void runtimeOnlyKernel() {}", options: nil)
        return library.makeFunction(name: "runtimeOnlyKernel")
    }
}
