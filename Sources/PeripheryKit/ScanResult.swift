import Foundation
import SourceGraph
import SystemPackage

public struct ScanResult {
    enum Annotation {
        case unused
        case assignOnlyProperty
        case unassignedOptionalProperty
        case enumCaseNeverConstructed
        case redundantProtocol(references: Set<Reference>, inherited: Set<String>)
        case redundantPublicAccessibility(modules: Set<String>)
        case redundantOpenAccessibility(modules: Set<String>)
        case missingFinal
        case redundantAccessLevel(RedundantAccessLevel)
        case emptyExtension
        case superfluousIgnoreCommand
        case unusedAssetCatalogSymbol(AssetCatalogSymbol)
        case missingMetalFunction
    }

    let declaration: Declaration
    let annotation: Annotation

    public var usrs: Set<String> {
        if case .superfluousIgnoreCommand = annotation {
            return declaration.usrs.mapSet { "superfluous-ignore-\($0)" }
        }
        return declaration.usrs
    }

    /// The ids earlier versions gave this result, which a baseline they wrote may still hold. An unused import and
    /// an empty extension were identified by their position, a String Catalog key by the absolute path of its catalog.
    func legacyUsrs(projectRoot: FilePath) -> Set<String> {
        let name = declaration.name
        let location = declaration.location

        switch (declaration.kind, annotation) {
        case (.module, .unused):
            return [SyntheticUsr.legacyModuleImport(name, at: location, projectRoot: projectRoot)]
        case (_, .emptyExtension):
            return [SyntheticUsr.legacyEmptyExtension(of: name, at: location, projectRoot: projectRoot)]
        case (.localizedString, .unused):
            return [SyntheticUsr.legacyLocalizedString(name, in: location.file.path)]
        default:
            return []
        }
    }
}

extension ScanResult.Annotation {
    /// The annotation name emitted in the `hints` of a report and accepted by `report_exclude`.
    var name: String {
        switch self {
        case .unused: "unused"
        case .assignOnlyProperty: "assignOnlyProperty"
        case .unassignedOptionalProperty: "unassignedOptionalProperty"
        case .enumCaseNeverConstructed: "enumCaseNeverConstructed"
        case .redundantProtocol: "redundantProtocol"
        case .redundantPublicAccessibility: "redundantPublicAccessibility"
        case .redundantOpenAccessibility: "redundantOpenAccessibility"
        case .missingFinal: "missingFinal"
        case .redundantAccessLevel: "redundantAccessLevel"
        case .emptyExtension: "emptyExtension"
        case .superfluousIgnoreCommand: "superfluousIgnoreCommand"
        case let .unusedAssetCatalogSymbol(symbol): symbol.kind.annotationName
        case .missingMetalFunction: "missingMetalFunction"
        }
    }

    /// Every value `name` can take. Some payloads cannot be built in this module, so the names are listed; a test
    /// checks this set against `name` for every case.
    static let allNames: Set<String> = Set([
        "unused", "assignOnlyProperty", "unassignedOptionalProperty", "enumCaseNeverConstructed", "redundantProtocol",
        "redundantPublicAccessibility", "redundantOpenAccessibility", "missingFinal", "redundantAccessLevel", "emptyExtension",
        "superfluousIgnoreCommand", "missingMetalFunction",
    ]).union(AssetCatalogSymbolKind.allCases.map(\.annotationName))
}
