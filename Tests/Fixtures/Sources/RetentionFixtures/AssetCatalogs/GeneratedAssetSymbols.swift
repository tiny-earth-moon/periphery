// Mirrors the GeneratedAssetSymbols.swift that Xcode generates for an asset catalog with a backwards
// deployment target, see testDetectsUnusedAssetCatalogColors.
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)

// MARK: - Color Symbols -

extension ColorResource {

    /// The "FixtureUnusedColor" asset catalog color resource.
    static let fixtureUnusedColor = ColorResource(name: "FixtureUnusedColor", bundle: resourceBundle)

    /// The "FixtureUsedColor" asset catalog color resource.
    static let fixtureUsedColor = ColorResource(name: "FixtureUsedColor", bundle: resourceBundle)

    /// The "FixtureResourceUsedColor" asset catalog color resource.
    static let fixtureResourceUsedColor = ColorResource(name: "FixtureResourceUsedColor", bundle: resourceBundle)

    /// The "AccentColor" asset catalog color resource.
    static let accent = ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "FixtureNamedColor" asset catalog color resource.
    static let fixtureNamedColor = ColorResource(name: "FixtureNamedColor", bundle: resourceBundle)

    /// The "FixtureXibColor" asset catalog color resource.
    static let fixtureXibColor = ColorResource(name: "FixtureXibColor", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
extension AppKit.NSColor {

    /// The "FixtureUnusedColor" asset catalog color.
    static var fixtureUnusedColor: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fixtureUnusedColor)
#else
        .init()
#endif
    }

    /// The "FixtureUsedColor" asset catalog color.
    static var fixtureUsedColor: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fixtureUsedColor)
#else
        .init()
#endif
    }

    /// The "FixtureResourceUsedColor" asset catalog color.
    static var fixtureResourceUsedColor: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fixtureResourceUsedColor)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
extension SwiftUI.Color {

    /// The "FixtureUnusedColor" asset catalog color.
    static var fixtureUnusedColor: SwiftUI.Color { .init(.fixtureUnusedColor) }

    /// The "FixtureUsedColor" asset catalog color.
    static var fixtureUsedColor: SwiftUI.Color { .init(.fixtureUsedColor) }

    /// The "FixtureResourceUsedColor" asset catalog color.
    static var fixtureResourceUsedColor: SwiftUI.Color { .init(.fixtureResourceUsedColor) }

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

#if canImport(AppKit)
extension AppKit.NSColor {

    /// Initialize a `NSColor` with a color resource.
    convenience init(resource: ColorResource) {
        self.init(named: NSColor.Name(resource.name), bundle: resource.bundle)!
    }

}
#endif

#if canImport(SwiftUI)
extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(_ resource: ColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}
#endif
