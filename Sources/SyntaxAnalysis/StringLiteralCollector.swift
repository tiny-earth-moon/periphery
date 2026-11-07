import Foundation
import SwiftSyntax

/// Collects the decoded value of every string literal of a source file without interpolation, whatever its type or
/// position.
public final class StringLiteralCollector: PeripherySyntaxNodeVisitor {
    public private(set) var values: Set<String> = []

    public init() {}

    public static func collect(from syntax: SourceFileSyntax) -> Set<String> {
        let collector = StringLiteralCollector()
        collector.walk(syntax)
        return collector.values
    }

    public func visit(_ node: StringLiteralExprSyntax) {
        if let value = node.representedLiteralValue {
            values.insert(value)
        }
    }
}
