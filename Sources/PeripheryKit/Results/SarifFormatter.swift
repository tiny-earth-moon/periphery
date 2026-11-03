import Configuration
import Foundation
import Logger
import Shared
import SourceGraph
import SystemPackage

/// Writes SARIF 2.1.0, the input format of GitHub code scanning. Paths are always relative to the project root and
/// resolved against the `%SRCROOT%` base id, whatever `--relative-results` says.
final class SarifFormatter: OutputFormatter {
    static let requiresRelativePaths = true

    static let schemaUri = "https://json.schemastore.org/sarif-2.1.0.json"
    static let baseId = "%SRCROOT%"
    static let fingerprintKey = "peripheryResult/v1"

    private static let informationUri = "https://github.com/tiny-earth-moon/outskirts"

    private struct Rule {
        let id: String
        let description: String
        let anchor: String
    }

    private static let rules: [Rule] = [
        Rule(id: "unused", description: "The declaration is never referenced", anchor: "analysis"),
        Rule(id: "assignOnlyProperty", description: "The property is assigned, but never read", anchor: "assign-only-properties"),
        Rule(id: "unassignedOptionalProperty", description: "The optional property is never assigned and is always nil", anchor: "unassigned-optional-analysis"),
        Rule(id: "redundantProtocol", description: "The protocol is never used as an existential type", anchor: "protocols-1"),
        Rule(id: "redundantPublicAccessibility", description: "The declaration is public but not used outside of its module", anchor: "redundant-public-accessibility"),
        Rule(id: "redundantOpenAccessibility", description: "The declaration is open but never subclassed or overridden outside of its module", anchor: "open--final-analysis"),
        Rule(id: "missingFinal", description: "The class or member could be final", anchor: "open--final-analysis"),
        Rule(id: "redundantAccessLevel", description: "The access level is already the default in its context", anchor: "redundant-access-level-analysis"),
        Rule(id: "emptyExtension", description: "The extension declares nothing", anchor: "empty-extension-analysis"),
        Rule(id: "superfluousIgnoreCommand", description: "The ignore comment is on a declaration that is referenced", anchor: "comment-commands"),
        Rule(id: "unusedAssetCatalogColor", description: "The asset catalog color is never referenced", anchor: "asset-catalog-colors"),
        Rule(id: "unusedAssetCatalogImage", description: "The asset catalog image is never referenced", anchor: "asset-catalog-images"),
    ]

    let configuration: Configuration
    let logger: Logger
    lazy var currentFilePath: FilePath = .current

    init(configuration: Configuration, logger: Logger) {
        self.logger = logger
        self.configuration = configuration
    }

    func format(_ results: [ScanResult], colored _: Bool) throws -> String? {
        let run: [String: Any] = [
            "tool": ["driver": driver()],
            "originalUriBaseIds": [Self.baseId: ["uri": rootUri()]],
            "results": results.map(sarifResult),
        ]
        let log: [String: Any] = [
            "$schema": Self.schemaUri,
            "version": "2.1.0",
            "runs": [run],
        ]

        return try serializeJSON(log)
    }

    // MARK: - Private

    private func driver() -> [String: Any] {
        [
            "name": "outskirts",
            "version": PeripheryVersion,
            "informationUri": Self.informationUri,
            "rules": Self.rules.map { rule in
                [
                    "id": rule.id,
                    "shortDescription": ["text": rule.description],
                    "helpUri": "https://github.com/tiny-earth-moon/outskirts#\(rule.anchor)",
                ] as [String: Any]
            },
        ]
    }

    private func rootUri() -> String {
        URL(fileURLWithPath: relativeResultsBase.string, isDirectory: true).absoluteString
    }

    private func sarifResult(_ result: ScanResult) -> [String: Any] {
        let descriptions = describe(result, colored: false)
        let ruleId = describe(result.annotation)
        let declarationLocation = declarationLocation(from: result.declaration)

        var object: [String: Any] = [
            "ruleId": ruleId,
            "level": "warning",
            "message": ["text": descriptions[0].1],
            "locations": [["physicalLocation": physicalLocation(declarationLocation)]],
            "partialFingerprints": [Self.fingerprintKey: fingerprint(ruleId: ruleId, ids: result.usrs)],
            "properties": [
                "kind": declarationKind(from: result.declaration),
                "accessibility": result.declaration.accessibility.value.rawValue,
                "modules": declarationLocation.file.modules.sorted(),
            ] as [String: Any],
        ]

        if let ruleIndex = Self.rules.firstIndex(where: { $0.id == ruleId }) {
            object["ruleIndex"] = ruleIndex
        }

        let related = descriptions.dropFirst()

        if !related.isEmpty {
            object["relatedLocations"] = related.enumerated().map { index, entry in
                [
                    "id": index + 1,
                    "physicalLocation": physicalLocation(entry.0),
                    "message": ["text": entry.1],
                ] as [String: Any]
            }
        }

        return object
    }

    private func physicalLocation(_ location: Location) -> [String: Any] {
        let path = outputPath(location).string
        let uri = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path

        return [
            "artifactLocation": ["uri": uri, "uriBaseId": Self.baseId],
            "region": ["startLine": location.line, "startColumn": location.column],
        ]
    }

    private func fingerprint(ruleId: String, ids: Set<String>) -> String {
        let input = ([ruleId] + ids.sorted()).joined(separator: "\n")
        return SHA256.hexDigest(of: Data(input.utf8))
    }
}
