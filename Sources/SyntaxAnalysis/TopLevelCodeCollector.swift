import Foundation
import SwiftSyntax

/// The source ranges of the top-level statements and expressions of a file, in source order.
///
/// Top-level code, such as the body of a `main.swift`, has no enclosing declaration, so the index store records its
/// references without a containing symbol. It always runs, so such references belong to no declaration.
public struct TopLevelCodeRanges {
    struct Position: Comparable {
        let line: Int
        let column: Int

        static func < (lhs: Position, rhs: Position) -> Bool {
            (lhs.line, lhs.column) < (rhs.line, rhs.column)
        }
    }

    struct Range {
        let start: Position
        let end: Position
    }

    let ranges: [Range]

    public var isEmpty: Bool {
        ranges.isEmpty
    }

    public func contains(line: Int, column: Int) -> Bool {
        let position = Position(line: line, column: column)
        // The ranges are disjoint and sorted: find the last one starting at or before the position.
        var low = 0
        var high = ranges.count

        while low < high {
            let middle = (low + high) / 2

            if ranges[middle].start <= position {
                low = middle + 1
            } else {
                high = middle
            }
        }

        guard low > 0 else { return false }

        return position <= ranges[low - 1].end
    }
}

/// Collects the top-level statements and expressions of a file, including those inside `#if` blocks. Declarations and
/// freestanding macro expansions are not collected.
public final class TopLevelCodeCollector {
    private let locationConverter: SourceLocationConverter
    private var ranges: [TopLevelCodeRanges.Range] = []

    private init(locationConverter: SourceLocationConverter) {
        self.locationConverter = locationConverter
    }

    public static func collect(
        from syntax: SourceFileSyntax,
        locationConverter: SourceLocationConverter
    ) -> TopLevelCodeRanges {
        let collector = TopLevelCodeCollector(locationConverter: locationConverter)
        collector.collect(syntax.statements)
        return TopLevelCodeRanges(ranges: collector.ranges)
    }

    private func collect(_ items: CodeBlockItemListSyntax) {
        for item in items {
            switch item.item {
            case let .decl(decl):
                guard let ifConfig = decl.as(IfConfigDeclSyntax.self) else { continue }

                for clause in ifConfig.clauses {
                    if case let .statements(statements) = clause.elements {
                        collect(statements)
                    }
                }
            case let .expr(expr):
                // Freestanding macros, such as `#Preview`, expand to declarations that hold their references.
                guard !expr.is(MacroExpansionExprSyntax.self) else { continue }

                ranges.append(range(of: item))
            case .stmt:
                ranges.append(range(of: item))
            }
        }
    }

    private func range(of item: CodeBlockItemSyntax) -> TopLevelCodeRanges.Range {
        let start = locationConverter.location(for: item.positionAfterSkippingLeadingTrivia)
        let end = locationConverter.location(for: item.endPositionBeforeTrailingTrivia)
        return TopLevelCodeRanges.Range(
            start: .init(line: start.line, column: start.column),
            end: .init(line: end.line, column: end.column)
        )
    }
}
