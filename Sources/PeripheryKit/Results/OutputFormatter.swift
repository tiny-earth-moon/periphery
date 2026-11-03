import Configuration
import Foundation
import Logger
import SourceGraph
import SystemPackage

public protocol OutputFormatter: AnyObject {
    var configuration: Configuration { get }
    var logger: Logger { get }
    var currentFilePath: FilePath { get set }

    /// Whether the output only makes sense with paths relative to the project root, whatever `relativeResults` says.
    static var requiresRelativePaths: Bool { get }

    init(configuration: Configuration, logger: Logger)
    func format(_ results: [ScanResult], colored: Bool) throws -> String?
}

public extension OutputFormatter {
    static var requiresRelativePaths: Bool {
        false
    }
}

extension OutputFormatter {
    func redundantConformanceHint(with inherited: Set<String>) -> String {
        var msg = "redundantConformance"
        if !inherited.isEmpty {
            msg += "(replace with: '\(inherited.sorted().joined(separator: ", "))')"
        }

        return msg
    }

    /// References are held in a set, whose order changes from one process to the next. Output must not depend on it.
    func sortedReferences(_ references: Set<Reference>) -> [Reference] {
        references.sorted {
            ($0.location, $0.usr, $0.kind.rawValue, $0.name, $0.declarationKind.rawValue)
                < ($1.location, $1.usr, $1.kind.rawValue, $1.name, $1.declarationKind.rawValue)
        }
    }

    /// Serializes with sorted keys, as dictionaries are hashed per process and would otherwise change the key order
    /// of every object from one run to the next.
    func serializeJSON(_ object: Any) throws -> String? {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(bytes: data, encoding: .utf8)
    }

    func describe(_ annotation: ScanResult.Annotation) -> String {
        switch annotation {
        case .unused:
            "unused"
        case .assignOnlyProperty:
            "assignOnlyProperty"
        case .unassignedOptionalProperty:
            "unassignedOptionalProperty"
        case .redundantProtocol:
            "redundantProtocol"
        case .redundantPublicAccessibility:
            "redundantPublicAccessibility"
        case .redundantOpenAccessibility:
            "redundantOpenAccessibility"
        case .missingFinal:
            "missingFinal"
        case .redundantAccessLevel:
            "redundantAccessLevel"
        case .emptyExtension:
            "emptyExtension"
        case .superfluousIgnoreCommand:
            "superfluousIgnoreCommand"
        case let .unusedAssetCatalogSymbol(symbol):
            symbol.kind.annotationName
        }
    }

    func describe(_ result: ScanResult, colored: Bool) -> [(Location, String)] {
        var description = ""
        var secondaryResults: [(Location, String)] = []
        let location = declarationLocation(from: result.declaration)
        let kindDisplayName = declarationKindDisplayName(from: result.declaration)
        let name = colored ? logger.colorize(result.declaration.name, .lightBlue) : result.declaration.name

        switch result.annotation {
        case .unused:
            description += "Unused \(kindDisplayName) '\(name)'"
        case .assignOnlyProperty:
            description += "Assign-only \(kindDisplayName) '\(name)' is assigned, but never used"
        case .unassignedOptionalProperty:
            description += "Optional property '\(name)' is never assigned (always nil)"
        case let .redundantProtocol(references, inherited):
            description += "Redundant protocol '\(name)' (never used as an existential type)"
            secondaryResults = sortedReferences(references).map {
                var msg = "Redundant protocol conformance '\(name)'"

                if !inherited.isEmpty {
                    msg += " (replace with '\(inherited.sorted().joined(separator: ", "))')"
                }

                return ($0.location, msg)
            }
        case let .redundantPublicAccessibility(modules):
            let modulesJoined = modules.sorted().joined(separator: ", ")
            description += "Redundant public accessibility for \(kindDisplayName) '\(name)' (not used outside of \(modulesJoined))"
        case .redundantOpenAccessibility:
            let capitalizedKind = kindDisplayName.prefix(1).uppercased() + kindDisplayName.dropFirst()
            let verb = result.declaration.kind == .class ? "subclassed" : "overridden"
            description += "\(capitalizedKind) '\(name)' is open but never \(verb) outside its module"
        case .missingFinal:
            let capitalizedKind = kindDisplayName.prefix(1).uppercased() + kindDisplayName.dropFirst()
            description += "\(capitalizedKind) '\(name)' could be final"
        case let .redundantAccessLevel(redundancy):
            description += "Redundant \(redundancy.accessibility.rawValue) access level for \(kindDisplayName) '\(name)' "
            if let context = redundancy.context, let parent = result.declaration.parent {
                description += "(already the default inside its \(context.rawValue) \(declarationKindDisplayName(from: parent)))"
            } else {
                description += "(already the default at the top level)"
            }
        case .emptyExtension:
            description += "Empty extension of '\(name)'"
        case .superfluousIgnoreCommand:
            description += "Superfluous ignore comment for \(kindDisplayName) '\(name)' (declaration is referenced and should not be ignored)"
        case let .unusedAssetCatalogSymbol(symbol):
            description += unusedAssetCatalogSymbolDescription(symbol, symbolName: name)
        }

        return [(location, description)] + secondaryResults
    }

    func unusedAssetCatalogSymbolDescription(_ symbol: AssetCatalogSymbol, symbolName: String) -> String {
        guard let assetName = symbol.assetName else {
            return "Unused asset catalog \(symbol.kind.displayName) '\(symbolName)' (asset name not found in the generated symbols)"
        }

        var description = "Unused asset catalog \(symbol.kind.displayName) '\(assetName)'"

        if !symbol.assetPaths.isEmpty {
            description += " (\(symbol.assetPaths.map { outputPath($0).string }.joined(separator: ", ")))"
        }

        return description
    }

    /// The directory that result paths are made relative to: `relative_results_base`, or the project root.
    var relativeResultsBase: FilePath {
        configuration.relativeResultsBase?.makeAbsolute(relativeTo: currentFilePath) ?? currentFilePath
    }

    func outputPath(_ location: Location) -> FilePath {
        outputPath(location.file.path)
    }

    func outputPath(_ file: FilePath) -> FilePath {
        var path = file.lexicallyNormalized()

        if configuration.relativeResults || Self.requiresRelativePaths, path.isAbsolute {
            path = path.relativeTo(relativeResultsBase).removingRoot()
        }

        return path
    }

    func locationDescription(_ location: Location) -> String {
        [
            outputPath(location).string,
            String(location.line),
            String(location.column),
        ]
        .joined(separator: ":")
    }

    func declarationKind(from declaration: Declaration) -> String {
        var kind = declaration.kind.rawValue

        if let overrideKind = declaration.commentCommands.kindOverride {
            kind = overrideKind
        }

        return kind
    }

    func declarationKindDisplayName(from declaration: Declaration) -> String {
        var kind = declaration.kind.displayName

        if let overrideKind = declaration.commentCommands.kindOverride {
            kind = overrideKind
        }

        return kind
    }

    func declarationLocation(from declaration: Declaration) -> Location {
        var location = declaration.location

        if let override = declaration.commentCommands.locationOverride {
            let (path, line, column) = override
            let sourceFile = SourceFile(path: path, modules: [])
            let overrideLocation = Location(file: sourceFile, line: line, column: column)
            location = overrideLocation
        }

        return location
    }
}

public extension OutputFormat {
    var requiresRelativePaths: Bool {
        formatter.requiresRelativePaths
    }

    var formatter: OutputFormatter.Type {
        switch self {
        case .xcode:
            XcodeFormatter.self
        case .csv:
            CsvFormatter.self
        case .codeclimate:
            CodeClimateFormatter.self
        case .json:
            JsonFormatter.self
        case .checkstyle:
            CheckstyleFormatter.self
        case .githubActions:
            GitHubActionsFormatter.self
        case .githubMarkdown:
            GitHubMarkdownFormatter.self
        case .gitlabCodeQuality:
            GitLabCodeQualityFormatter.self
        case .sarif:
            SarifFormatter.self
        }
    }
}
