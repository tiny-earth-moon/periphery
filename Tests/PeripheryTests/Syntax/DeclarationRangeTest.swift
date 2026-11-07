import Foundation
import Logger
import Shared
@testable import SourceGraph
@testable import SyntaxAnalysis
@testable import TestShared
import XCTest

/// The ranges collected by the shared syntax walk, which the json format emits as `range`.
final class DeclarationRangeTest: XCTestCase {
    private var declarations: [Location: DeclarationSyntaxVisitor.Result]!
    private var imports: [ImportStatement]!
    private var emptyExtensions: [EmptyExtensionSyntaxVisitor.Result]!
    private var parameters: [Parameter]!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let shell = ShellImpl(logger: Logger(quiet: true, verbose: false, colorMode: .never))
        let swiftVersion = try SwiftVersion(shell: shell)
        let multiplexingVisitor = try MultiplexingSyntaxVisitor(file: fixturePath, swiftVersion: swiftVersion)
        let declarationVisitor = multiplexingVisitor.add(DeclarationSyntaxVisitor.self)
        let importVisitor = multiplexingVisitor.add(ImportSyntaxVisitor.self)
        let emptyExtensionVisitor = multiplexingVisitor.add(EmptyExtensionSyntaxVisitor.self)
        multiplexingVisitor.visit()
        declarations = declarationVisitor.resultsByLocation
        imports = importVisitor.importStatements
        emptyExtensions = emptyExtensionVisitor.results
        parameters = UnusedParameterParser.parse(
            file: fixturePath,
            syntax: multiplexingVisitor.syntax,
            locationConverter: multiplexingVisitor.locationConverter,
            parseProtocols: false
        ).flatMap(\.parameters)
    }

    override func tearDown() {
        declarations = nil
        imports = nil
        emptyExtensions = nil
        parameters = nil
        super.tearDown()
    }

    func testDocumentedAndAttributedType_flagsTheDocCommentAndTheAttributes() {
        XCTAssertEqual(range(line: 8, column: 20), DeclarationRange(
            start: position(8, 1),
            end: position(17, 2),
            attributesStart: position(7, 1),
            docCommentStart: position(5, 1)
        ))
    }

    func testNestedDeclarations_coverTheirOwnLines() {
        XCTAssertEqual(range(line: 10, column: 10), DeclarationRange(start: position(10, 5), end: position(10, 25), attributesStart: position(9, 5)))
        XCTAssertEqual(range(line: 12, column: 12), DeclarationRange(start: position(12, 5), end: position(14, 6)))
        XCTAssertEqual(range(line: 13, column: 13), DeclarationRange(start: position(13, 9), end: position(13, 23)))
    }

    func testPlainCommentOrBlankLine_detachesTheDocComment() {
        XCTAssertEqual(range(line: 21, column: 6), DeclarationRange(start: position(21, 1), end: position(23, 2)))
        XCTAssertEqual(range(line: 27, column: 11), DeclarationRange(start: position(27, 1), end: position(27, 36)))
    }

    func testEnumCaseElements_shareTheRangeOfTheirDeclaration() {
        let expected = DeclarationRange(start: position(22, 5), end: position(22, 18))
        XCTAssertEqual(range(line: 22, column: 10), expected)
        XCTAssertEqual(range(line: 22, column: 15), expected)
    }

    func testImportAndEmptyExtension_carryTheirRange() {
        XCTAssertEqual(imports.map(\.range), [DeclarationRange(start: position(1, 1), end: position(1, 18))])
        XCTAssertEqual(emptyExtensions.map(\.range), [DeclarationRange(start: position(27, 1), end: position(27, 36))])
    }

    func testParameters_excludeTheirTrailingComma() {
        let ranges = parameters.sorted { $0.location < $1.location }.map(\.range)
        XCTAssertEqual(ranges, [
            DeclarationRange(start: position(16, 21), end: position(16, 31)),
            DeclarationRange(start: position(16, 33), end: position(16, 49)),
        ])
    }

    // MARK: - Private

    private var fixturePath: SourceFile {
        let path = FixturesProjectPath.appending("Sources/DeclarationVisitorFixtures/RangeFixture.swift")
        return SourceFile(path: path, modules: ["DeclarationVisitorFixtures"])
    }

    private func range(line: Int, column: Int) -> DeclarationRange? {
        declarations[Location(file: fixturePath, line: line, column: column)]?.range
    }

    private func position(_ line: Int, _ column: Int) -> SourcePosition {
        SourcePosition(line: line, column: column)
    }
}
