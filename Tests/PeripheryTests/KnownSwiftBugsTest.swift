import Configuration
@testable import Indexer
@testable import PeripheryKit
import Shared
@testable import SourceGraph
@testable import TestShared
import XCTest

/// Pins what the Swift index store itself records for the constructs of the "Known Swift bugs" table of
/// docs/troubleshooting.md, before any outskirts mutator runs. When a toolchain changes the raw behaviour, the matching
/// test fails and the table row and the workaround (if any) must be revisited.
final class KnownSwiftBugsTest: FixtureSourceGraphTestCase {
    private func rawGraph() -> SourceGraph {
        let configuration = Configuration()
        configuration.quiet = true
        configuration.retainPublic = true
        configuration.buildFilenameMatchers()

        let plan = IndexPlan(
            sourceFiles: Self.plan.sourceFiles.filter { $0.key.path == testFixturePath },
            plistPaths: [],
            xibPaths: [],
            xcDataModelPaths: Self.plan.xcDataModelPaths,
            xcMappingModelPaths: Self.plan.xcMappingModelPaths,
            xcStringsPaths: Self.plan.xcStringsPaths,
            indexStorePaths: Self.plan.indexStorePaths
        )
        let graph = SourceGraph(configuration: configuration, logger: Self.logger)
        let pipeline = IndexPipeline(
            plan: plan,
            graph: SourceGraphMutex(graph: graph),
            logger: Self.logger.contextualized(with: "index"),
            configuration: configuration,
            swiftVersion: Self.swiftVersion
        )
        try! pipeline.perform()
        return graph
    }

    /// Declarations of `kind` named `name`, optionally inside the type `parent`, that something references through a
    /// plain (non-related) reference.
    private func hasUseReference(_ graph: SourceGraph, kind: Declaration.Kind, name: String, in parent: String? = nil) throws -> Bool {
        let declarations = graph.declarations(ofKind: kind).filter {
            $0.name == name && (parent == nil || $0.parent?.name == parent)
        }
        XCTAssertEqual(declarations.count, 1, "expected exactly one \(kind.rawValue) \(name)")
        let declaration = try XCTUnwrap(declarations.first)
        return graph.references(to: declaration).contains { $0.kind == .normal }
    }

    // MARK: - swiftlang/swift#56165

    private static let literalConstructors: [(parent: String, name: String)] = [
        ("FixtureArrayLiteral", "init(arrayLiteral:)"),
        ("FixtureDictionaryLiteral", "init(dictionaryLiteral:)"),
        ("FixtureStringLiteral", "init(stringLiteral:)"),
        ("FixtureIntegerLiteral", "init(integerLiteral:)"),
        ("FixtureFloatLiteral", "init(floatLiteral:)"),
        ("FixtureBooleanLiteral", "init(booleanLiteral:)"),
        ("FixtureNilLiteral", "init(nilLiteral:)"),
        ("FixtureUnicodeScalarLiteral", "init(unicodeScalarLiteral:)"),
        ("FixtureExtendedGraphemeClusterLiteral", "init(extendedGraphemeClusterLiteral:)"),
    ]

    /// Fixed upstream (reported resolved since Swift 6.1.2): the index store relates a literal initializer to the
    /// literal that calls it, so outskirts needs no workaround.
    func testLiteralConstructorsAreRelated() throws {
        let graph = rawGraph()

        for (parent, name) in Self.literalConstructors {
            let related = try hasUseReference(graph, kind: .functionConstructor, name: name, in: parent)
            XCTAssertTrue(related, "\(parent).\(name) is not referenced by the index store")
        }

        analyze(retainPublic: true) {
            for (parent, name) in Self.literalConstructors {
                assertReferenced(.struct(parent)) {
                    self.assertReferenced(.functionConstructor(name))
                }
            }
        }
    }

    // MARK: - swiftlang/swift#56541

    /// The static getter used as a subscript key is referenced. outskirts has no workaround for this issue, and the
    /// graph-level `testStaticMemberUsedAsSubscriptKey` has passed on every supported toolchain.
    func testStaticGetterAsSubscriptKeyIsRelated() throws {
        let graph = rawGraph()
        let related = try hasUseReference(graph, kind: .varStatic, name: "someVar", in: "FixtureEnumSubscript")
        XCTAssertTrue(related, "raw index store behaviour for #56541 changed")
    }

    // MARK: - swiftlang/swift#56189

    /// Verified on Swift 6.4: `appendInterpolation` is referenced from the string literal. On older toolchains the
    /// reference is expected to be missing (the upstream bug), and `StringInterpolationAppendInterpolationRetainer`
    /// stays as the safety net; the raw behaviour is pinned on both sides.
    func testAppendInterpolationFromLiteralIsRelated() throws {
        analyze(retainPublic: true) {
            assertReferenced(.extensionStruct("DefaultStringInterpolation")) {
                self.assertReferenced(.functionMethodInstance("appendInterpolation(fixtureLabel:)"))
            }
        }

        let graph = rawGraph()
        let related = try hasUseReference(graph, kind: .functionMethodInstance, name: "appendInterpolation(fixtureLabel:)")
        #if compiler(>=6.4)
            XCTAssertTrue(related, "raw index store behaviour for #56189 changed")
        #else
            // Pinned on Swift 6.4 (Xcode 27); the Swift of Xcode 26 already records the reference, older Linux
            // toolchains do not.
            try XCTSkipIf(related, "#56189: the raw reference is pinned on Swift 6.4 (Xcode 27) and later")
            XCTAssertFalse(related, "raw index store behaviour for #56189 changed")
        #endif
    }

    #if os(macOS)

        // MARK: - swiftlang/swift#56327

        /// Fixed by https://github.com/swiftlang/swift/pull/86167 (Swift 6.3): the optional `@objc` requirement
        /// implemented in a subclass is related to the protocol requirement. Before 6.3 no relation is recorded.
        /// outskirts has no workaround for this issue.
        func testOptionalObjcMethodInSubclassIsRelated() throws {
            let graph = rawGraph()
            let declarations = graph.declarations(ofKind: .functionMethodInstance).filter {
                $0.name == "fileManager(_:shouldRemoveItemAtPath:)" && $0.parent?.name == "FixtureOptionalSubclass"
            }
            XCTAssertEqual(declarations.count, 1)
            let related = try XCTUnwrap(declarations.first).related.contains { $0.kind == .related }

            #if compiler(>=6.3)
                XCTAssertTrue(related, "raw index store behaviour for #56327 changed")
            #else
                XCTAssertFalse(related, "raw index store behaviour for #56327 changed")
            #endif
        }
    #endif
}
