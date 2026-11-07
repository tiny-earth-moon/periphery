import SourceGraph
import SwiftParser
import SwiftSyntax
@testable import SyntaxAnalysis
import SystemPackage
import XCTest

/// The indexer runs its syntax collectors in a single shared walk: each must find what it finds when walking alone.
final class SharedSyntaxWalkTest: XCTestCase {
    private static let source = #"""
    #if os(macOS)
    let platformName = macOnly()
    #if os(iOS)
    let nested = nestedOnly()
    #endif
    #else
    let platformName = otherOnly("else")
    #endif

    #if os(Linux)
    let after = afterOnly()
    #endif

    struct Item {
        var title: String?
    }

    func apply(@Clamped(0 ... 5) level: Int) {
        let handler = { (@Trimmed value: String) in print(value) }
        let path = \Item.title
        print(level, "plain \(handler)")
        dump(path)
    }
    """#

    private let file = SourceFile(path: FilePath("/fixture.swift"), modules: ["Fixture"])
    private lazy var syntax = Parser.parse(source: Self.source)
    private lazy var converter = SourceLocationConverter(fileName: "/fixture.swift", tree: syntax)

    func testCollectorsFindTheSameInASharedWalk() {
        let builder = SourceLocationBuilder(file: file, locationConverter: converter)
        let walker = ForwardingSyntaxVisitor()
        let platformConditionalNames = walker.add(PlatformConditionalNameCollector(locationConverter: converter))
        let parameterAttributeNames = walker.add(ParameterAttributeNameCollector())
        let stringLiterals = walker.add(StringLiteralCollector())
        let synthesizedUses = walker.add(SynthesizedUseCollector(sourceLocationBuilder: builder))
        let keyPathComponents = walker.add(KeyPathComponentCollector(sourceLocationBuilder: builder))
        walker.walk(syntax)

        XCTAssertEqual(platformConditionalNames.names, PlatformConditionalNameCollector.collect(from: syntax))
        XCTAssertEqual(parameterAttributeNames.names, ParameterAttributeNameCollector.collect(from: syntax))
        XCTAssertEqual(stringLiterals.values, StringLiteralCollector.collect(from: syntax))
        XCTAssertEqual(synthesizedUses.uses, SynthesizedUseCollector.collect(from: syntax, file: file, locationConverter: converter))
        XCTAssertEqual(keyPathComponents.locations, KeyPathComponentCollector.collect(from: syntax, file: file, locationConverter: converter))
    }

    func testPlatformConditionalBlockCollectedWholeIsNotVisitedAgain() {
        let collector = PlatformConditionalNameCollector(locationConverter: converter)
        collector.walk(syntax)

        XCTAssertEqual(collector.names.sorted(), ["afterOnly", "iOS", "macOnly", "nestedOnly", "os", "otherOnly"])
        XCTAssertEqual(collector.sites["nestedOnly"], [.init(line: 4, condition: "#if os(macOS)")])
        XCTAssertEqual(collector.sites["afterOnly"], [.init(line: 11, condition: "#if os(Linux)")])
    }
}
