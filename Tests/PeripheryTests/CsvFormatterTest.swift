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
            class,Tagged,final|public,"available(macOS 15, *)",internal,s:3Lib6TaggedC,/Sources/Lib/Tagged.swift:2:20,unused
            class,"unused, raw helper",,,internal,s:3Lib6TaggedC,/Sources/Lib/Tagged.swift:2:20,unused
            """
        )
    }

    func testCsvOutput_placesModifiersAndAttributesUnderTheirOwnColumns() throws {
        let output = try format([
            result(
                name: "Tagged",
                attributes: [DeclarationAttribute(name: "available", arguments: "macOS 15, *")],
                modifiers: ["final"]
            ),
        ])
        let rows = output.components(separatedBy: "\n").map(splitFields)
        let header = try XCTUnwrap(rows.first)
        let row = try XCTUnwrap(rows.last)

        XCTAssertEqual(row[try XCTUnwrap(header.firstIndex(of: "Modifiers"))], "final")
        XCTAssertEqual(row[try XCTUnwrap(header.firstIndex(of: "Attributes"))], "available(macOS 15, *)")
    }

    func testCsvOutput_quotesRedundantConformanceHint() throws {
        let file = SourceFile(path: FilePath("/Sources/Lib/Tagged.swift"), modules: ["Lib"])
        let reference = Reference(
            name: "Proto",
            kind: .normal,
            declarationKind: .protocol,
            usr: "s:3Lib5ProtoP",
            location: Location(file: file, line: 7, column: 3)
        )
        var scanResult = result(name: "Proto")
        scanResult = ScanResult(
            declaration: scanResult.declaration,
            annotation: .redundantProtocol(references: [reference], inherited: ["A", "B"])
        )

        let output = try format([scanResult])

        XCTAssertTrue(output.contains("\"redundantConformance(replace with: 'A, B')\""))
        for row in output.components(separatedBy: "\n") {
            XCTAssertEqual(splitFields(row).count, 8, row)
        }
    }

    func testCsvOutput_doublesQuotesInsideFields() throws {
        let output = try format([result(name: "say \"hi\"")])

        XCTAssertTrue(output.contains("\"say \"\"hi\"\"\""))
        XCTAssertEqual(splitFields(output.components(separatedBy: "\n")[1])[1], "say \"hi\"")
    }

    func testCsvOutput_everyRowHasEightFields() throws {
        let output = try format([
            result(name: "unused, raw helper", attributes: [DeclarationAttribute(name: "available", arguments: "macOS 15, *")], modifiers: ["final", "public"]),
            result(name: "say \"hi\""),
            result(name: "multi\nline"),
        ])

        for row in splitRows(output) {
            XCTAssertEqual(splitFields(row).count, 8, row)
        }
        XCTAssertEqual(splitFields(try XCTUnwrap(splitRows(output).first)).count, 8)
    }

    // MARK: - Helpers

    private func format(_ results: [ScanResult]) throws -> String {
        try XCTUnwrap(CsvFormatter(configuration: Configuration(), logger: logger).format(results, colored: false))
    }

    /// Splits CSV text into records, honouring quoted newlines.
    private func splitRows(_ text: String) -> [String] {
        var rows: [String] = []
        var current = ""
        var inQuotes = false
        for char in text {
            if char == "\"" {
                inQuotes.toggle()
            }
            if char == "\n", !inQuotes {
                rows.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        rows.append(current)
        return rows
    }

    /// RFC 4180 field split: quoted fields, doubled quotes.
    private func splitFields(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = row.makeIterator()
        var pending = iterator.next()
        while let char = pending {
            pending = iterator.next()
            if inQuotes {
                if char == "\"" {
                    if pending == "\"" {
                        current.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
