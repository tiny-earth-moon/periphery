import Configuration
import Foundation
@testable import Indexer
import Logger
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

final class XCDataModelClassNamesTest: XCTestCase {
    private static let contents = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="22522" systemVersion="23B81" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="Entity" representedClassName="Entity" syncable="YES">
            <attribute name="tags" optional="YES" attributeType="Transformable" valueTransformerName="TagsTransformer" customClassName="NSArray"/>
            <attribute name="plain" optional="YES" attributeType="String"/>
            <attribute name="empty" optional="YES" attributeType="Transformable" valueTransformerName="" customClassName=""/>
        </entity>
        <entity name="Qualified" representedClassName=".Qualified" syncable="YES">
            <attribute name="payload" optional="YES" attributeType="Transformable" valueTransformerName="Support.PayloadTransformer"/>
        </entity>
        <entity name="Custom" representedClassName="CustomEntity" syncable="YES" codeGenerationType="class"/>
    </model>
    """

    private func parseReferences() throws -> [AssetReference] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Model-\(UUID().uuidString).xcdatamodeld")
        let version = directory.appendingPathComponent("Model.xcdatamodel")
        try FileManager.default.createDirectory(at: version, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        try Self.contents.write(to: version.appendingPathComponent("contents"), atomically: true, encoding: .utf8)

        return try XCDataModelParser(input: .directory(FilePath(directory.path))).parse()
    }

    func testParserCollectsValueTransformerAndRepresentedClassNames() throws {
        let names = try Set(parseReferences().map(\.name))

        XCTAssertTrue(names.isSuperset(of: ["Entity", "TagsTransformer", "NSArray", "Qualified", "PayloadTransformer", "CustomEntity"]), "\(names)")
        XCTAssertFalse(names.contains(""))
    }

    func testClassesNamedByTheModelAreRetained() throws {
        let graph = SourceGraph(configuration: Configuration(), logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let swiftVersion = try SwiftVersion(shell: ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never)))
        let file = SourceFile(path: FilePath("/tmp/model-classes.swift"), modules: ["App"])

        let names = ["Entity", "TagsTransformer", "PayloadTransformer", "CustomEntity", "Widget"]
        var declarations: [String: Declaration] = [:]
        for (index, name) in names.enumerated() {
            let declaration = Declaration(name: name, kind: .class, usrs: ["usr_\(name)"], location: Location(file: file, line: index + 1, column: 1))
            graph.add(declaration)
            declarations[name] = declaration
        }

        try parseReferences().forEach { graph.add($0) }
        AssetReferenceRetainer(graph: graph, configuration: Configuration(), swiftVersion: swiftVersion).mutate()

        for name in ["Entity", "TagsTransformer", "PayloadTransformer", "CustomEntity"] {
            XCTAssertTrue(graph.isRetained(try XCTUnwrap(declarations[name])), "\(name) should be retained")
        }
        // Control: a class that the model does not name stays unretained.
        XCTAssertFalse(graph.isRetained(try XCTUnwrap(declarations["Widget"])))
    }
}
