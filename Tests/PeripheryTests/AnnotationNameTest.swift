import Configuration
import Logger
@testable import PeripheryKit
@testable import SourceGraph
import SystemPackage
import XCTest

final class AnnotationNameTest: XCTestCase {
    private let expectedNames: [(ScanResult.Annotation, String)] = [
        (.unused, "unused"),
        (.assignOnlyProperty, "assignOnlyProperty"),
        (.unassignedOptionalProperty, "unassignedOptionalProperty"),
        (.enumCaseNeverConstructed, "enumCaseNeverConstructed"),
        (.redundantProtocol(references: [], inherited: []), "redundantProtocol"),
        (.redundantPublicAccessibility(modules: []), "redundantPublicAccessibility"),
        (.redundantOpenAccessibility(modules: []), "redundantOpenAccessibility"),
        (.missingFinal, "missingFinal"),
        (.redundantAccessLevel(RedundantAccessLevel(accessibility: .internal, context: nil)), "redundantAccessLevel"),
        (.emptyExtension, "emptyExtension"),
        (.superfluousIgnoreCommand, "superfluousIgnoreCommand"),
        (.unusedAssetCatalogSymbol(AssetCatalogSymbol(kind: .color, assetName: nil, assetPaths: [])), "unusedAssetCatalogColor"),
        (.unusedAssetCatalogSymbol(AssetCatalogSymbol(kind: .image, assetName: nil, assetPaths: [])), "unusedAssetCatalogImage"),
        (.missingMetalFunction, "missingMetalFunction"),
    ]

    private func result(_ annotation: ScanResult.Annotation) -> ScanResult {
        let file = SourceFile(path: FilePath("/App/File.swift"), modules: ["App"])
        let declaration = Declaration(name: "x", kind: .functionFree, usrs: ["s:x"], location: Location(file: file, line: 1, column: 1))
        return ScanResult(declaration: declaration, annotation: annotation)
    }

    func testResultKindIdentifier_pinsEveryAnnotationName() {
        for (annotation, name) in expectedNames {
            XCTAssertEqual(ResultKind.identifier(of: result(annotation)), "\(name).function.free")
        }
    }

    func testResultKindAnnotationNames_listsExactlyEveryAnnotationName() {
        XCTAssertEqual(ResultKind.annotationNames, Set(expectedNames.map(\.1)))
    }

    func testFormatterHints_pinEveryAnnotationName() throws {
        let formatter = JsonFormatter(configuration: Configuration(), logger: Logger(quiet: true, verbose: false, colorMode: .never))
        for (annotation, name) in expectedNames {
            XCTAssertEqual(formatter.describe(annotation), name)
        }
    }
}
