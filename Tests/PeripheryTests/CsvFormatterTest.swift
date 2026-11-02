import Configuration
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class CsvFormatterTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

    private func result(name: String, attributes: Set<DeclarationAttribute> = [], modifiers: Set<String> = []) -> ScanResult {
        let file = SourceFile(path: FilePath("/Sources/Lib/Tagged.swift"), modules: ["Lib"])
        let declaration = Declaration(name: name, kind: .class, usrs: ["s:3Lib6TaggedC"], location: Location(file: file, line: 2, column: 20))
        declaration.attributes = attributes
        declaration.modifiers = modifiers
        return ScanResult(declaration: declaration, annotation: .unused)
    }

    func testCsvOutput_usesCorrectColumnsAndEscapesCommaFields() throws {
        let output = try CsvFormatter(configuration: Configuration(), logger: logger).format([
            result(
                name: "Tagged",
                attributes: [DeclarationAttribute(name: "available", arguments: "macOS 15, *")],
                modifiers: ["final", "public"]
            ),
            result(name: "unused, raw helper"),
        ], colored: false)

        XCTAssertEqual(
            output,
            """
            Kind,Name,Modifiers,Attributes,Accessibility,IDs,Location,Hints
            class,Tagged,final|public,"available(macOS 15, *)",internal,s:3Lib6TaggedC,Sources/Lib/Tagged.swift:2:20,unused
            class,"unused, raw helper",,,internal,s:3Lib6TaggedC,Sources/Lib/Tagged.swift:2:20,unused
            """
        )
    }
}
