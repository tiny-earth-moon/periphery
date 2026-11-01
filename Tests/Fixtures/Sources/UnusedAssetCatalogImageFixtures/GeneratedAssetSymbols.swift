// Mirrors the GeneratedAssetSymbols.swift that Xcode generates for an asset catalog with a backwards
// deployment target, see UnusedAssetCatalogImageTest. Xcode generates no symbol for the AppIcon app icon set.
import Foundation
#if canImport(AppKit)
import AppKit
#endif

private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)

// MARK: - Color Symbols -

extension ColorResource {

    /// The "FixtureImageTestColor" asset catalog color resource.
    static let fixtureImageTestColor = ColorResource(name: "FixtureImageTestColor", bundle: resourceBundle)

}

// MARK: - Image Symbols -

extension ImageResource {

    /// The "FixtureUnusedImage" asset catalog image resource.
    static let fixtureUnusedImage = ImageResource(name: "FixtureUnusedImage", bundle: resourceBundle)

    /// The "FixtureUnusedSymbol" asset catalog image resource.
    static let fixtureUnusedSymbol = ImageResource(name: "FixtureUnusedSymbol", bundle: resourceBundle)

    /// The "FixtureUsedImage" asset catalog image resource.
    static let fixtureUsedImage = ImageResource(name: "FixtureUsedImage", bundle: resourceBundle)

    /// The "FixtureResourceUsedImage" asset catalog image resource.
    static let fixtureResourceUsedImage = ImageResource(name: "FixtureResourceUsedImage", bundle: resourceBundle)

    /// The "FixtureNamedImage" asset catalog image resource.
    static let fixtureNamedImage = ImageResource(name: "FixtureNamedImage", bundle: resourceBundle)

    /// The "FixtureXibImage" asset catalog image resource.
    static let fixtureXibImage = ImageResource(name: "FixtureXibImage", bundle: resourceBundle)

    /// The "FixtureXibButtonImage" asset catalog image resource.
    static let fixtureXibButtonImage = ImageResource(name: "FixtureXibButtonImage", bundle: resourceBundle)

    /// The "FixtureLaunchImage" asset catalog image resource.
    static let fixtureLaunchImage = ImageResource(name: "FixtureLaunchImage", bundle: resourceBundle)

}

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
extension AppKit.NSImage {

    /// The "FixtureUnusedImage" asset catalog image.
    static var fixtureUnusedImage: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fixtureUnusedImage)
#else
        .init()
#endif
    }

    /// The "FixtureUsedImage" asset catalog image.
    static var fixtureUsedImage: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fixtureUsedImage)
#else
        .init()
#endif
    }

    /// The "FixtureNamedImage" asset catalog image.
    static var fixtureNamedImage: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fixtureNamedImage)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Backwards Deployment Support -

/// A color resource.
struct ColorResource: Swift.Hashable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `ColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct ImageResource: Swift.Hashable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `ImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

#if canImport(AppKit)
extension AppKit.NSImage {

    /// Initialize a `NSImage` with an image resource.
    convenience init(resource: ImageResource) {
        let image = resource.bundle.image(forResource: NSImage.Name(resource.name))!
        self.init(data: image.tiffRepresentation!)!
    }

}
#endif
