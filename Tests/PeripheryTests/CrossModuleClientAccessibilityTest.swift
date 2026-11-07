import Configuration
import Logger
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

/// Pins which files count as clients outside the declaring module for the redundant public and redundant open
/// analyses: a file of another module that does not `@testable import` the declaring module. Files may belong to
/// several modules, and so may the declaration.
final class CrossModuleClientAccessibilityTest: XCTestCase {
    private struct Client {
        let modules: Set<String>
        var testableImports: [String] = []
    }

    private static let cases: [(declModules: Set<String>, client: Client, isCrossModule: Bool)] = [
        (["A"], Client(modules: ["B"]), true),
        (["A"], Client(modules: ["B"], testableImports: ["A"]), false),
        (["A"], Client(modules: ["B"], testableImports: ["C"]), true),
        (["A"], Client(modules: ["A"]), false),
        (["A"], Client(modules: ["A", "B"]), true),
        (["A"], Client(modules: ["A", "B"], testableImports: ["A"]), false),
        (["A", "B"], Client(modules: ["B"]), false),
        (["A", "B"], Client(modules: ["C"]), true),
        (["A", "B"], Client(modules: ["C"], testableImports: ["B"]), false),
        (["A", "B"], Client(modules: ["B", "C"]), true),
    ]

    private var swiftVersion: SwiftVersion!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        swiftVersion = try SwiftVersion(shell: ShellImpl(logger: logger))
    }

    func testRedundantPublicAccessibility() throws {
        for (declModules, client, isCrossModule) in Self.cases {
            let graph = makeGraph()
            let decl = makeDeclaration("Base", kind: .class, modules: declModules, accessibility: .public)
            graph.add(decl)
            let clientDecl = makeDeclaration("client()", kind: .functionFree, modules: client.modules, client: client)
            graph.add(clientDecl)
            graph.add(makeReference(to: decl, kind: .normal, from: clientDecl), from: clientDecl)
            graph.indexingComplete()

            try RedundantExplicitPublicAccessibilityMarker(
                graph: graph,
                configuration: Configuration(),
                swiftVersion: swiftVersion
            ).mutate()

            XCTAssertEqual(
                !graph.redundantPublicAccessibility.keys.contains(decl),
                isCrossModule,
                "declared in \(declModules.sorted()), referenced from \(client)"
            )
        }
    }

    func testRedundantOpenAccessibility() throws {
        for (declModules, client, isCrossModule) in Self.cases {
            let graph = makeGraph()
            let base = makeDeclaration("Base", kind: .class, modules: declModules, accessibility: .open)
            let member = makeDeclaration("member()", kind: .functionMethodInstance, modules: declModules, accessibility: .open)
            member.parent = base
            base.declarations.insert(member)
            graph.add([base, member])

            let subclass = makeDeclaration("Subclass", kind: .class, modules: client.modules, client: client)
            let override = makeDeclaration("member()", kind: .functionMethodInstance, modules: client.modules, client: client)
            override.modifiers.insert("override")
            override.parent = subclass
            subclass.declarations.insert(override)
            graph.add([subclass, override])
            graph.add(makeReference(to: base, kind: .related, from: subclass), from: subclass)
            graph.add(makeReference(to: member, kind: .related, from: override), from: override)
            graph.indexingComplete()

            let configuration = Configuration()
            configuration.enableOpenFinalAnalysis = true
            try OpenFinalAccessibilityMarker(graph: graph, configuration: configuration, swiftVersion: swiftVersion).mutate()

            let context = "declared in \(declModules.sorted()), subclassed from \(client)"
            XCTAssertEqual(!graph.redundantOpenAccessibility.keys.contains(base), isCrossModule, context)
            XCTAssertEqual(!graph.redundantOpenAccessibility.keys.contains(member), isCrossModule, context)
        }
    }

    // MARK: - Private

    private func makeGraph() -> SourceGraph {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        return SourceGraph(configuration: Configuration(), logger: logger)
    }

    private func makeDeclaration(
        _ name: String,
        kind: Declaration.Kind,
        modules: Set<String>,
        accessibility: Accessibility = .internal,
        client: Client? = nil
    ) -> Declaration {
        let path = "\(client == nil ? "Decl" : "Client")\(modules.sorted().joined()).swift"
        let file = SourceFile(path: FilePath(path), modules: modules)
        let location = Location(file: file, line: 1, column: 1)
        file.importStatements = (client?.testableImports ?? []).map {
            ImportStatement(
                module: $0,
                isTestable: true,
                isExported: false,
                isConditional: false,
                location: location,
                endLocation: location,
                commentCommands: []
            )
        }
        let decl = Declaration(name: name, kind: kind, usrs: ["\(path):\(name)"], location: location)
        decl.accessibility = .init(value: accessibility, isExplicit: accessibility != .internal)
        return decl
    }

    private func makeReference(to decl: Declaration, kind: Reference.Kind, from parent: Declaration) -> Reference {
        let reference = Reference(
            name: decl.name,
            kind: kind,
            declarationKind: decl.kind,
            usr: decl.usrs.first!,
            location: parent.location
        )
        reference.parent = parent
        return reference
    }
}
