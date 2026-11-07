import SourceGraph
import SwiftParser
import SwiftSyntax
@testable import SyntaxAnalysis
import SystemPackage
import XCTest

/// Pins what the per-file syntax collectors of the indexer find in a source that exercises all of them at once.
final class SyntaxCollectorsContractTest: XCTestCase {
    private static let source = #"""
    import Metal

    #if os(macOS)
    let platformName = macOnly()
    #if os(iOS)
    let nested = nestedOnly()
    #endif
    #else
    let platformName = otherOnly()
    #endif

    struct Item {
        var title: String?
        var count = 0
    }

    func apply(@Clamped(0 ... 5) level: Int, @Wrappers.Lowered name: String) {
        let handler = { (@Trimmed value: String) in print(value) }
        let item = Item()
        let path = \Item.title
        var other = item
        other[keyPath: \.count] = 1
        print(item, "plain \(level) and \(Item(), format: .x)")
        dump(make<Int>())
        _ = String(describing: other)
        _ = "multi\nline"
        _ = #"raw"#
        _ = "interpolated \("nested")"
        _ = path
        _ = handler
    }

    func metal(device: MTLDevice, library: MTLLibrary, descriptor: MTLFunctionDescriptor) throws {
        _ = library.makeFunction(name: "vertexMain")
        descriptor.name = "fragmentMain"
        _ = try device.makeLibrary(source: "", options: nil)
        var archive: MTLBinaryArchive?
        _ = archive
    }

    func patterns(value: Shape?, values: [Shape]) throws {
        switch value {
        case .circle(let radius)?: _ = radius
        case let Shape.square(.some(side)): _ = side
        default: break
        }
        if case .line = value {}
        for case .dot in values {}
        do {} catch Failure.broken {}
    }
    """#

    private let file = SourceFile(path: FilePath("/fixture.swift"), modules: ["Fixture"])
    private lazy var syntax = Parser.parse(source: Self.source)
    private lazy var converter = SourceLocationConverter(fileName: "/fixture.swift", tree: syntax)

    func testStringLiterals() {
        XCTAssertEqual(
            StringLiteralCollector.collect(from: syntax).sorted(),
            ["", "fragmentMain", "multi\nline", "nested", "raw", "vertexMain"]
        )
    }

    func testParameterAttributeNames() {
        XCTAssertEqual(ParameterAttributeNameCollector.collect(from: syntax).sorted(), ["Clamped", "Lowered", "Trimmed"])
    }

    func testKeyPathComponentLocations() {
        let locations = KeyPathComponentCollector.collect(from: syntax, file: file, locationConverter: converter)
        XCTAssertEqual(render(locations), ["20:22"])
    }

    func testSynthesizedUses() {
        let uses = SynthesizedUseCollector.collect(from: syntax, file: file, locationConverter: converter)
        let rendered = uses.map { use in
            let target = use.typeName ?? use.location.map { "\($0.line):\($0.column)" } ?? "?"
            return "\(use.kind) \(target)"
        }

        XCTAssertEqual(rendered.sorted(), [
            "description 18:55",
            "description 19:16",
            "description 21:17",
            "description 23:11",
            "description 23:26",
            "description 25:28",
            "description Int",
            "dump 24:10",
        ])
    }

    func testMetalFunctionNames() {
        let result = MetalFunctionNameCollector.collect(from: syntax, file: file, locationConverter: converter)
        let candidates = result.candidates.map { candidate in
            let property = candidate.propertyLocation.map { " at \($0.line):\($0.column)" } ?? ""
            return "\(candidate.reference.name ?? "?") \(candidate.reference.location.line):\(candidate.reference.location.column)\(property)"
        }

        XCTAssertEqual(candidates, ["vertexMain 34:36", "fragmentMain 35:23 at 35:16"])
        XCTAssertEqual(result.runtimeLibrarySites.map(\.call), ["makeLibrary(source:)", "MTLBinaryArchive"])
    }

    func testPlatformConditionalNames() {
        XCTAssertEqual(
            PlatformConditionalNameCollector.collect(from: syntax).sorted(),
            ["iOS", "macOnly", "nestedOnly", "os", "otherOnly"]
        )
    }

    func testEnumCasePatterns() {
        let collector = EnumCasePatternCollector(file: file, locationConverter: converter)
        collector.walk(syntax)

        XCTAssertEqual(
            render(collector.sites),
            ["43:11 call", "44:20 call", "44:28 call in 44:20", "47:14 name", "48:15 name", "49:25 name"]
        )
        XCTAssertEqual(
            collector.conditionalNames.sorted(),
            ["iOS", "macOnly", "nested", "nestedOnly", "os", "otherOnly", "platformName"]
        )
    }

    /// The Metal and enum case pattern collectors share the indexer's single walk: they find the same as alone.
    func testSharedWalkMatchesStandaloneWalks() {
        let builder = SourceLocationBuilder(file: file, locationConverter: converter)
        let metal = MetalFunctionNameCollector(sourceLocationBuilder: builder)
        let patterns = EnumCasePatternCollector(file: file, locationConverter: converter)
        let strings = StringLiteralCollector()
        ForwardingSyntaxVisitor(visitors: [strings, metal, patterns]).walk(syntax)

        let standaloneMetal = MetalFunctionNameCollector.collect(from: syntax, file: file, locationConverter: converter)
        let standalonePatterns = EnumCasePatternCollector(file: file, locationConverter: converter)
        standalonePatterns.walk(syntax)

        XCTAssertEqual(metal.result.candidates, standaloneMetal.candidates)
        XCTAssertEqual(metal.result.runtimeLibrarySites, standaloneMetal.runtimeLibrarySites)
        XCTAssertEqual(patterns.sites, standalonePatterns.sites)
        XCTAssertEqual(patterns.conditionalNames, standalonePatterns.conditionalNames)
        XCTAssertEqual(strings.values, StringLiteralCollector.collect(from: syntax))
    }

    // MARK: - Private

    private func render(_ sites: [Location: EnumCasePatternSite]) -> [String] {
        sites.map { location, site in
            let call = site.enclosingCall.map { " in \($0.line):\($0.column)" } ?? ""
            return "\(location.line):\(location.column) \(site.shape)\(call)"
        }.sorted()
    }

    private func render(_ locations: Set<Location>) -> [String] {
        locations.map { "\($0.line):\($0.column)" }.sorted()
    }
}
