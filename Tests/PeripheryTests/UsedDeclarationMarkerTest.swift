import Configuration
import Logger
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

final class UsedDeclarationMarkerTest: XCTestCase {
    /// Deep enough to overflow the main thread stack when the reference graph is walked by recursion.
    private static let chainLength = 200_000

    private let location = Location(
        file: SourceFile(path: FilePath("Chain.swift"), modules: ["Chain"]),
        line: 1,
        column: 1
    )

    private func makeGraph() -> SourceGraph {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        return SourceGraph(configuration: Configuration(), logger: logger)
    }

    private func mutate(_ graph: SourceGraph) {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let swiftVersion = SwiftVersion(shell: ShellImpl(logger: logger))
        UsedDeclarationMarker(graph: graph, configuration: Configuration(), swiftVersion: swiftVersion).mutate()
    }

    private func makeFunction(_ index: Int) -> Declaration {
        Declaration(name: "step\(index)()", kind: .functionFree, usrs: ["step\(index)"], location: location)
    }

    private func makeReference(to index: Int, kind: Reference.Kind, from declaration: Declaration) -> Reference {
        let reference = Reference(
            name: "step\(index)()",
            kind: kind,
            declarationKind: .functionFree,
            usr: "step\(index)",
            location: location
        )
        reference.parent = declaration
        return reference
    }

    /// Adds `length` functions to the graph, each referencing the next one, alternating between references and related
    /// references. When `isCyclic` is set the last function references the first.
    private func addChain(to graph: SourceGraph, length: Int, isCyclic: Bool = false) -> [Declaration] {
        let functions = (0 ..< length).map(makeFunction)

        for (index, function) in functions.enumerated() {
            graph.add(function)

            let next = index + 1
            guard next < length || isCyclic else { continue }

            let kind: Reference.Kind = index.isMultiple(of: 2) ? .normal : .related
            graph.add(makeReference(to: next % length, kind: kind, from: function), from: function)
        }

        return functions
    }

    func testDeepChainFromRetainedDeclarationIsMarkedUsedWithoutStackOverflow() {
        let graph = makeGraph()
        let functions = addChain(to: graph, length: Self.chainLength)
        graph.markRetained(functions[0])
        graph.indexingComplete()

        mutate(graph)

        XCTAssertEqual(graph.usedDeclarations.count, Self.chainLength)
        XCTAssertTrue(graph.unusedDeclarations.isEmpty)
    }

    func testDeepChainFromRootReferenceIsMarkedUsedWithoutStackOverflow() {
        let graph = makeGraph()
        _ = addChain(to: graph, length: Self.chainLength)
        graph.add(Reference(
            name: "step0()",
            kind: .normal,
            declarationKind: .functionFree,
            usr: "step0",
            location: location
        ))
        graph.indexingComplete()

        mutate(graph)

        XCTAssertEqual(graph.usedDeclarations.count, Self.chainLength)
        XCTAssertTrue(graph.unusedDeclarations.isEmpty)
    }

    func testOnlyDeclarationsReachableFromRetainedDeclarationsAreMarkedUsed() {
        let graph = makeGraph()
        let functions = addChain(to: graph, length: 6, isCyclic: true)
        let orphan = makeFunction(100)
        let orphanTarget = makeFunction(101)
        graph.add(orphan)
        graph.add(orphanTarget)
        graph.add(makeReference(to: 101, kind: .normal, from: orphan), from: orphan)
        graph.markRetained(functions[3])
        graph.indexingComplete()

        mutate(graph)

        XCTAssertEqual(graph.usedDeclarations, Set(functions), "A cycle must terminate and mark every member used")
        XCTAssertEqual(graph.unusedDeclarations, [orphan, orphanTarget])
    }
}
