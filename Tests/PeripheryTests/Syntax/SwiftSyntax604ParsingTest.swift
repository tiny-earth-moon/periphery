import SwiftParser
import SwiftSyntax
import XCTest

final class SwiftSyntax604ParsingTest: XCTestCase {
    func testModernSyntaxParsesWithoutDiagnostics() {
        let source = """
        protocol Store: Sendable {
            associatedtype Value: ~Copyable
            func load() async throws(StoreError) -> Value
        }

        enum StoreError: Error { case missing }

        struct Box<T: ~Copyable>: ~Copyable {
            var value: T
            consuming func take() -> T { value }
        }

        @concurrent func fetch() async -> Int { 1 }

        nonisolated(nonsending) func run() async {}

        func sum<each T: Numeric>(_ values: repeat each T) {}

        func describe(_ value: some Sendable, of items: [any Sendable]) {
            let result: Int = if items.isEmpty { 0 } else { 1 }
            _ = result
        }

        struct Pair { let first: Int; let second: Int }
        func unpack(_ pair: Pair) -> Int {
            switch consume pair {
            case let .init(first: first, second: second): first + second
            }
        }

        @MainActor let label = #"raw \\(string)"#
        """

        let syntax = Parser.parse(source: source)

        XCTAssertFalse(syntax.hasError, "Parser reported errors for \(syntax.description)")
    }
}
