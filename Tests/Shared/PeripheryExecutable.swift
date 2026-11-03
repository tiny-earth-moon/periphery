import Foundation

/// Locates the built `periphery` product: next to the test bundle (macOS, native build system) or next to the test runner (Swift 6.4 build system).
func locatePeripheryExecutable(near testClass: AnyClass) throws -> URL {
    let candidates = [
        Bundle(for: testClass).bundleURL.deletingLastPathComponent(),
        Bundle.main.bundleURL,
        Bundle.main.bundleURL.deletingLastPathComponent(),
    ].map { $0.appendingPathComponent("periphery") }
    if let url = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
        return url
    }

    throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: candidates[0].path, NSLocalizedDescriptionKey: "Build the 'periphery' product before running this test"])
}
