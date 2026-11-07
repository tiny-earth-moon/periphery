import Configuration
import Foundation
import Shared

final class XCTestRetainer: SourceGraphMutator {
    private let graph: SourceGraph
    private let testCaseClassNames: Set<String>

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        testCaseClassNames = Set(configuration.externalTestCaseClasses + ["XCTestCase"])
    }

    func mutate() {
        let immediateTestCaseClasses = graph.declarations(ofKind: .class).filter {
            $0.related.contains {
                $0.declarationKind == .class && self.testCaseClassNames.contains($0.name)
            }
        }

        let subclasses = immediateTestCaseClasses.flatMapSet { graph.subclasses(of: $0) }
        let testCaseClasses = subclasses.union(immediateTestCaseClasses)

        for testCaseClass in testCaseClasses {
            graph.markRetainedWithAncestors(testCaseClass, reason: RetentionReason(Self.self, "XCTestCase subclass \(testCaseClass.name)"))
            let methods = testCaseClass.declarations.filter { $0.kind == .functionMethodInstance }

            for method in methods {
                let name = method.name

                if name.hasPrefix("test"), name.hasSuffix("()") {
                    graph.markRetained(method, reason: RetentionReason(Self.self, "test method of XCTestCase subclass \(testCaseClass.name)"))
                }
            }
        }
    }
}
