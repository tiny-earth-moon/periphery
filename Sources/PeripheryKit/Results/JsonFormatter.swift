import Configuration
import Foundation
import Logger
import SourceGraph
import SystemPackage

final class JsonFormatter: SummaryFormatter {
    let configuration: Configuration
    let logger: Logger
    lazy var currentFilePath: FilePath = .current

    init(configuration: Configuration, logger: Logger) {
        self.logger = logger
        self.configuration = configuration
    }

    func format(_ results: [ScanResult], colored _: Bool) throws -> String? {
        try serializeJSON(resultObjects(results))
    }

    /// An object that holds the results under `results` and the summary under `summary`, where the report without
    /// the summary is the bare array of results.
    func format(_ results: [ScanResult], summary: ScanSummary, colored _: Bool) throws -> String? {
        try serializeJSON(["results": resultObjects(results), "summary": summaryObject(summary)])
    }

    // MARK: - Private

    private func resultObjects(_ results: [ScanResult]) -> [Any] {
        var jsonObject: [Any] = []

        for result in results {
            let location = declarationLocation(from: result.declaration)
            var object: [AnyHashable: Any] = [
                "kind": declarationKind(from: result.declaration),
                "modules": location.file.modules.sorted(),
                "name": result.declaration.name,
                "modifiers": result.declaration.modifiers.sorted(),
                "attributes": result.declaration.attributes.sorted().map(\.description),
                "accessibility": result.declaration.accessibility.value.rawValue,
                "ids": result.declaration.usrs.sorted(),
                "hints": [describe(result.annotation)],
                "location": locationDescription(location),
            ]

            if let range = result.declaration.range, result.declaration.commentCommands.locationOverride == nil {
                object["range"] = rangeObject(range)
            }

            if case let .unusedAssetCatalogSymbol(symbol) = result.annotation {
                object["asset"] = [
                    "name": symbol.assetName.map { $0 as Any } ?? NSNull(),
                    "paths": symbol.assetPaths.map { outputPath($0).string },
                ]
            }

            jsonObject.append(object)

            switch result.annotation {
            case let .redundantProtocol(references, inherited):
                for ref in sortedReferences(references) {
                    let object: [AnyHashable: Any] = [
                        "kind": ref.declarationKind.rawValue,
                        "modules": ref.location.file.modules.sorted(),
                        "name": ref.name,
                        "modifiers": [String](),
                        "attributes": [String](),
                        "accessibility": "",
                        "ids": [ref.usr],
                        "hints": [redundantConformanceHint(with: inherited)],
                        "location": locationDescription(ref.location),
                    ]
                    jsonObject.append(object)
                }
            default:
                break
            }
        }

        return jsonObject
    }

    private func rangeObject(_ range: DeclarationRange) -> [String: Any] {
        var object: [String: Any] = [
            "start": positionObject(range.start),
            "end": positionObject(range.end),
        ]
        if let attributesStart = range.attributesStart {
            object["attributesStart"] = positionObject(attributesStart)
        }
        if let docCommentStart = range.docCommentStart {
            object["docCommentStart"] = positionObject(docCommentStart)
        }
        return object
    }

    private func positionObject(_ position: SourcePosition) -> [String: Int] {
        ["line": position.line, "column": position.column]
    }
}
