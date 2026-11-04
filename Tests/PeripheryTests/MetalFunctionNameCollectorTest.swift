@testable import Indexer
import SourceGraph
import SwiftParser
import SwiftSyntax
@testable import SyntaxAnalysis
import SystemPackage
import XCTest

final class MetalFunctionNameCollectorTest: XCTestCase {
    private func runtimeLibraryCalls(_ source: String) -> [String] {
        let syntax = Parser.parse(source: source)
        let file = SourceFile(path: FilePath("/fixture.swift"), modules: ["Fixture"])
        let converter = SourceLocationConverter(fileName: "/fixture.swift", tree: syntax)
        return MetalFunctionNameCollector
            .collect(from: syntax, file: file, locationConverter: converter)
            .runtimeLibrarySites
            .map(\.call)
    }

    func testRecognizesTheCallsThatCreateALibraryAtRunTime() {
        let source = """
        func f(device: MTLDevice, url: URL, data: DispatchData, descriptor: MTLStitchedLibraryDescriptor) throws {
            _ = try device.makeLibrary(source: "", options: nil)
            _ = try device.makeLibrary(source: "")
            _ = try device.makeLibrary(URL: url)
            _ = try device.makeLibrary(filepath: "a.metallib")
            _ = try device.makeLibrary(data: data)
            _ = try device.makeLibrary(stitchedDescriptor: descriptor)
            _ = try device.makeBinaryArchive(descriptor: MTLBinaryArchiveDescriptor())
        }
        """

        XCTAssertEqual(runtimeLibraryCalls(source), [
            "makeLibrary(source:)", "makeLibrary(source:)", "makeLibrary(URL:)", "makeLibrary(filepath:)",
            "makeLibrary(data:)", "makeLibrary(stitchedDescriptor:)", "makeBinaryArchive",
        ])
    }

    func testRecognizesABinaryArchiveType() {
        XCTAssertEqual(runtimeLibraryCalls("var archive: MTLBinaryArchive?"), ["MTLBinaryArchive"])
    }

    func testIgnoresTheDefaultLibrary() {
        let source = """
        func f(device: MTLDevice) throws {
            _ = device.makeDefaultLibrary()
            _ = try device.makeDefaultLibrary(bundle: .main)
            _ = device.makeLibrary()
            _ = try device.makeLibrary(bundle: .main)
        }
        """

        XCTAssertEqual(runtimeLibraryCalls(source), [])
    }
}
