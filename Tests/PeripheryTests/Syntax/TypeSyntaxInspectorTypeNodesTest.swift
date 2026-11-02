import Foundation
@testable import SourceGraph
import SwiftParser
import SwiftSyntax
@testable import SyntaxAnalysis
import SystemPackage
@testable import TestShared
import XCTest

final class TypeSyntaxInspectorTypeNodesTest: XCTestCase {
    func testInlineArrayType() {
        XCTAssertEqual(typeNames(of: InlineArrayTypeSyntax.self, in: "let value: [2 of Element]"), ["Element"])
    }

    func testInlineArrayTypeWithGenericElement() {
        XCTAssertEqual(
            typeNames(of: InlineArrayTypeSyntax.self, in: "let value: [3 of Wrapper<Element>]"),
            ["Wrapper", "Element"]
        )
    }

    func testInlineArrayTypeWithGenericCount() {
        XCTAssertEqual(
            typeNames(of: InlineArrayTypeSyntax.self, in: "struct Buffer<let N: Int> { var value: [N of Element] }"),
            ["N", "Element"]
        )
    }

    func testPackExpansionType() {
        XCTAssertEqual(
            typeNames(of: PackExpansionTypeSyntax.self, in: "func make<each T>() -> (repeat Box<each T>) {}"),
            ["Box", "T"]
        )
    }

    func testPackElementType() {
        XCTAssertEqual(
            typeNames(of: PackElementTypeSyntax.self, in: "func make<each T>(_ values: repeat each T) {}"),
            ["T"]
        )
    }

    func testPackExpansionTypeAsTupleElement() {
        XCTAssertEqual(
            typeNames(of: TupleTypeSyntax.self, in: "func make<each T>() -> (repeat Box<each T>) {}"),
            ["Box", "T"]
        )
    }

    func testNamedOpaqueReturnType() {
        XCTAssertEqual(
            typeNames(of: NamedOpaqueReturnTypeSyntax.self, in: "func make() -> <T: Constraint> Container<T> {}"),
            ["Constraint", "Container", "T"]
        )
    }

    func testUnlistedTypeNodeContributesItsDescendantTypes() {
        XCTAssertEqual(typeNames(of: SuppressedTypeSyntax.self, in: "func make<T: ~Copyable>() {}"), ["Copyable"])
    }

    // MARK: - Private

    private func typeNames(of nodeType: (some TypeSyntaxProtocol).Type, in source: String) -> Set<String> {
        let tree = Parser.parse(source: source)
        let file = SourceFile(path: FilePath("/Fixture.swift"), modules: ["Fixture"])
        let converter = SourceLocationConverter(fileName: file.path.string, tree: tree)
        let inspector = TypeSyntaxInspector(sourceLocationBuilder: .init(file: file, locationConverter: converter))

        guard let node = firstNode(ofType: nodeType, in: Syntax(tree)) else {
            XCTFail("No \(nodeType) found in the source.")
            return []
        }

        return Set(inspector.types(for: TypeSyntax(node)).map(\.text))
    }

    private func firstNode<T: SyntaxProtocol>(ofType nodeType: T.Type, in node: Syntax) -> T? {
        if let match = node.as(nodeType) {
            return match
        }

        for child in node.children(viewMode: .sourceAccurate) {
            if let match = firstNode(ofType: nodeType, in: child) {
                return match
            }
        }

        return nil
    }
}
