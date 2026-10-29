import Foundation
import SwiftSyntax

/// Collects the decoded value of every string literal of a source file without interpolation, whatever its type or
/// position.
public final class StringLiteralCollector: SyntaxVisitor {
    public private(set) var values: Set<String> = []

    public init() {
        super.init(viewMode: .sourceAccurate)
    }

    public static func collect(from syntax: SourceFileSyntax) -> Set<String> {
        let collector = StringLiteralCollector()
        collector.walk(syntax)
        return collector.values
    }

    override public func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        if let value = node.representedLiteralValue {
            values.insert(value)
        }

        return .visitChildren
    }
}
