import AppKit

public struct FixtureStruct1500 {
    public func images() -> [NSImage?] {
        [NSImage.fixtureUsedImage, NSImage(resource: ImageResource.fixtureResourceUsedImage), NSImage(named: "FixtureNamedImage")]
    }
}
