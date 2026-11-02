import Configuration
import Logger
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

/// `@implementation` needs an imported C or Objective-C declaration to implement, which a SwiftPM fixture cannot
/// provide, so the retainer is exercised on a synthetic graph.
final class LinkageAttributeRetainerTest: XCTestCase {
    private var graph: SourceGraph!
    private var file: SourceFile!

    override func setUp() {
        super.setUp()

        let configuration = Configuration()
        graph = SourceGraph(configuration: configuration, logger: Logger(quiet: true, verbose: false, colorMode: .never))
        file = SourceFile(path: FilePath("/Widgets/Widget.swift"), modules: ["Widgets"])
    }

    private func declaration(_ name: String, _ kind: Declaration.Kind, line: Int, attributes: Set<DeclarationAttribute> = [], parent: Declaration? = nil) -> Declaration {
        let decl = Declaration(name: name, kind: kind, usrs: ["usr:\(name)"], location: Location(file: file, line: line, column: 1))
        decl.attributes = attributes
        decl.parent = parent
        parent?.declarations.insert(decl)
        graph.add(decl)
        return decl
    }

    private func mutate() throws {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let swiftVersion = try SwiftVersion(shell: ShellImpl(logger: logger))
        LinkageAttributeRetainer(graph: graph, configuration: Configuration(), swiftVersion: swiftVersion).mutate()
    }

    func testRetainsImplementationExtensionWithItsMembers() throws {
        let ext = declaration("Widget", .extensionClass, line: 1, attributes: [DeclarationAttribute(name: "implementation", arguments: nil)])
        let method = declaration("render()", .functionMethodInstance, line: 2, parent: ext)
        let plain = declaration("Other", .extensionClass, line: 5)
        let plainMethod = declaration("other()", .functionMethodInstance, line: 6, parent: plain)

        try mutate()

        XCTAssertTrue(graph.isRetained(ext))
        XCTAssertTrue(graph.isRetained(method))
        XCTAssertFalse(graph.isRetained(plain))
        XCTAssertFalse(graph.isRetained(plainMethod))
    }

    func testRetainsObjcImplementationExtensionWithItsMembers() throws {
        let ext = declaration("Widget", .extensionClass, line: 1, attributes: [DeclarationAttribute(name: "_objcImplementation", arguments: nil)])
        let method = declaration("render()", .functionMethodInstance, line: 2, parent: ext)

        try mutate()

        XCTAssertTrue(graph.isRetained(ext))
        XCTAssertTrue(graph.isRetained(method))
    }
}
