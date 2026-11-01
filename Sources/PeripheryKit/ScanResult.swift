import Foundation
import SourceGraph

public struct ScanResult {
    enum Annotation {
        case unused
        case assignOnlyProperty
        case unassignedOptionalProperty
        case redundantProtocol(references: Set<Reference>, inherited: Set<String>)
        case redundantPublicAccessibility(modules: Set<String>)
        case redundantOpenAccessibility(modules: Set<String>)
        case missingFinal
        case superfluousIgnoreCommand
        case unusedAssetCatalogSymbol(AssetCatalogSymbol)
    }

    let declaration: Declaration
    let annotation: Annotation

    public var usrs: Set<String> {
        if case .superfluousIgnoreCommand = annotation {
            return declaration.usrs.mapSet { "superfluous-ignore-\($0)" }
        }
        return declaration.usrs
    }
}
