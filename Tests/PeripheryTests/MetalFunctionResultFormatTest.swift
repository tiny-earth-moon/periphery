import Configuration
import Foundation
import Logger
@testable import PeripheryKit
import SourceGraph
import SystemPackage
import XCTest

final class MetalFunctionResultFormatTest: XCTestCase {
    private let logger = Logger(quiet: true, verbose: false, colorMode: .never)
    private let root = FilePath("/Project")

    private func results() -> [ScanResult] {
        let shaders = SourceFile(path: root.appending("Shaders/Blur.metal"), modules: [])
        let unused = Declaration(
            name: "blurFragment",
            kind: .metalFunction,
            usrs: [SyntheticUsr.metalFunction("blurFragment", in: shaders.path, projectRoot: root)],
            location: Location(file: shaders, line: 12, column: 15)
        )

        let renderer = SourceFile(path: root.appending("Sources/App/Renderer.swift"), modules: ["App"])
        let missing = Declaration(
            name: "blurKernel",
            kind: .metalFunction,
            usrs: [SyntheticUsr.missingMetalFunction("blurKernel", in: renderer.path, projectRoot: root)],
            location: Location(file: renderer, line: 8, column: 41)
        )

        return [
            ScanResult(declaration: unused, annotation: .unused),
            ScanResult(declaration: missing, annotation: .missingMetalFunction),
        ]
    }

    func testXcodeOutput_describesBothResultKinds() throws {
        let output = try XcodeFormatter(configuration: Configuration(), logger: logger).format(results(), colored: false)

        XCTAssertEqual(output, """
        /Project/Shaders/Blur.metal:12:15: warning: Unused Metal function 'blurFragment'
        /Project/Sources/App/Renderer.swift:8:41: warning: Metal function 'blurKernel' not found in any .metal file
        """)
    }

    func testJsonOutput_carriesTheKindHintAndId() throws {
        let output = try XCTUnwrap(JsonFormatter(configuration: Configuration(), logger: logger).format(results(), colored: false))
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]])

        XCTAssertEqual(objects.map { $0["kind"] as? String }, ["metal_function", "metal_function"])
        XCTAssertEqual(objects.map { $0["hints"] as? [String] }, [["unused"], ["missingMetalFunction"]])
        XCTAssertEqual(objects.map { $0["ids"] as? [String] }, [
            ["metal:Shaders/Blur.metal:blurFragment"],
            ["metal-missing:Sources/App/Renderer.swift:blurKernel"],
        ])
    }

    func testEveryFormat_rendersBothResultKinds() throws {
        for format in OutputFormat.allCases {
            let output = try format.formatter.init(configuration: Configuration(), logger: logger).format(results(), colored: false)
            XCTAssertTrue(output?.contains("blurKernel") == true, "\(format)")
            XCTAssertTrue(output?.contains("blurFragment") == true, "\(format)")
        }
    }

    func testBaseline_roundTripsAndMatchesBothResultKinds() throws {
        let baseline = Baseline.written(from: results(), union: nil, projectRoot: root)
        let decoded = try JSONDecoder().decode(Baseline.self, from: baseline.encoded())

        XCTAssertEqual(decoded, baseline)
        XCTAssertEqual(decoded.entries.map(\.kind), ["metal_function", "metal_function"])
        XCTAssertEqual(decoded.entries.map(\.file), ["Sources/App/Renderer.swift", "Shaders/Blur.metal"])

        let matcher = BaselineMatcher(decoded, projectRoot: root)
        for result in results() {
            XCTAssertEqual(matcher.match(result), .current, result.declaration.name)
        }
    }

    func testResultKind_isTheMissingMetalFunctionAnnotation() throws {
        XCTAssertEqual(ResultKind.identifier(of: results()[1]), "missingMetalFunction.metal_function")
        XCTAssertTrue(ResultKind.isValid("missingMetalFunction"))
        XCTAssertTrue(ResultKind.isValid("unused.metal_function"))
    }
}
