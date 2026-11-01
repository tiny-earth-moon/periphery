import Configuration
import Foundation
import SystemPackage

/// A kind of asset catalog resource for which Xcode generates Swift symbols in `GeneratedAssetSymbols.swift`.
public enum AssetCatalogSymbolKind: String, CaseIterable {
    case color

    /// The kinds whose unused symbols are detected with the given configuration.
    public static func detected(by configuration: Configuration) -> [Self] {
        allCases.filter { $0.isDetected(by: configuration) }
    }

    /// Name of the generated resource type whose initializer receives the asset name,
    /// e.g. `ColorResource(name: "AccentColor", bundle: resourceBundle)`.
    public var resourceTypeName: String {
        switch self {
        case .color: "ColorResource"
        }
    }

    /// Names of the types extended with a static symbol for each asset of this kind.
    public var symbolTypeNames: Set<String> {
        switch self {
        case .color: [resourceTypeName, "Color", "ShapeStyle", "UIColor", "NSColor"]
        }
    }

    /// Extension of the asset directories of this kind in an asset catalog.
    public var assetDirectoryExtension: String {
        switch self {
        case .color: "colorset"
        }
    }

    /// Annotation name of the results, as emitted in the `hints` of a report and accepted by `report_exclude`.
    public var annotationName: String {
        switch self {
        case .color: "unusedAssetCatalogColor"
        }
    }

    public var displayName: String {
        switch self {
        case .color: "color"
        }
    }

    private func isDetected(by configuration: Configuration) -> Bool {
        switch self {
        case .color: configuration.detectUnusedAssetCatalogColors
        }
    }
}

/// An asset catalog resource whose generated Swift symbols are all unused.
public struct AssetCatalogSymbol: Hashable {
    public let kind: AssetCatalogSymbolKind
    /// The asset name in the catalog, `nil` when it is not found in the generated file.
    public let assetName: String?
    /// The asset directories found in the asset catalogs of the project, e.g. `Assets.xcassets/AccentColor.colorset`.
    public let assetPaths: [FilePath]

    public init(kind: AssetCatalogSymbolKind, assetName: String?, assetPaths: [FilePath]) {
        self.kind = kind
        self.assetName = assetName
        self.assetPaths = assetPaths
    }
}
