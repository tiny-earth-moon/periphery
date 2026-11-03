import Foundation
import SourceGraph
import SystemPackage

public struct ScanResult {
    enum Annotation {
        case unused
        case assignOnlyProperty
        case unassignedOptionalProperty
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
