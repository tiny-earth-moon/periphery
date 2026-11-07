import Configuration
import Foundation
import SourceGraph
import SystemPackage

/// Explains, for `scan --explain`, why each declaration matching a query is reported, used or retained, from what the
/// source graph recorded during the analysis (see `SourceGraph.recordsExplanations`).
public struct DeclarationExplainer {
    private static let maximumListedFiles = 5

    private let graph: SourceGraph
    private let configuration: Configuration

    public init(graph: SourceGraph, configuration: Configuration) {
        self.graph = graph
        self.configuration = configuration
    }

    /// The explanations of the declarations matching each query: a name (`draw()`, `draw` or `Beta.draw()`), a USR, or
    /// a `file:line` (or `file:line:column`) location.
    public func explain(_ queries: [String]) -> String {
        queries.map(explain(query:)).joined(separator: "\n\n")
    }

    // MARK: - Private

    private func explain(query: String) -> String {
        let matches = declarations(matching: query)
        guard !matches.isEmpty else { return "No declaration matches '\(query)'." }

        return matches.map(explanation(of:)).joined(separator: "\n")
    }

    // MARK: Matching

    private func declarations(matching query: String) -> [Declaration] {
        if let declaration = graph.declaration(withUsr: query) {
            return [declaration]
        }

        if let match = query.wholeMatch(of: #/(.+\.swift):(\d+)(?::(\d+))?/#), let line = Int(match.output.2) {
            let column = match.output.3.flatMap { Int($0) }
            return graph.allDeclarations.filter { declaration in
                declaration.location.line == line
                    && (column == nil || declaration.location.column == column)
                    && isFile(declaration.location.file.path, matching: String(match.output.1))
            }.sorted()
        }

        let baseQuery = Self.baseName(of: query)
        return graph.allDeclarations.filter { declaration in
            guard !declaration.isImplicit else { return false }

            let qualifiedName = qualifiedName(of: declaration)
            return [declaration.name, qualifiedName].contains(query)
                || (baseQuery == query && [Self.baseName(of: declaration.name), Self.baseName(of: qualifiedName)].contains(query))
        }.sorted()
    }

    private func isFile(_ path: FilePath, matching queryPath: String) -> Bool {
        let query = FilePath(queryPath)
        if query.isAbsolute {
            return path.lexicallyNormalized() == query.lexicallyNormalized()
        }

        if !configuration.projectRoot.isEmpty, path.lexicallyNormalized() == configuration.projectRoot.pushing(query).lexicallyNormalized() {
            return true
        }

        return path.string.hasSuffix("/" + query.lexicallyNormalized().string)
    }

    private static func baseName(of name: String) -> String {
        String(name.prefix { $0 != "(" })
    }

    // MARK: Explanations

    private func explanation(of declaration: Declaration) -> String {
        let heading = describe(declaration)

        if graph.usedDeclarations.contains(declaration) {
            return usedExplanation(of: declaration, heading: heading)
        }

        if graph.assignOnlyProperties.contains(declaration) {
            return "\(heading) is reported: it is assigned, but never read"
        }

        if let unusedAncestor = unusedAncestor(of: declaration) {
            let retention = graph.isRetained(declaration) ? ", although it is retained: \(retentionReasons(of: declaration))" : ""
            return "\(heading) is unused: it is inside \(describe(unusedAncestor)), which is unused\(retention)"
        }

        return unusedExplanation(of: declaration, heading: heading)
    }

    private func usedExplanation(of declaration: Declaration, heading: String) -> String {
        let chain = referenceChain(to: declaration)
        let isRetained = graph.isRetained(declaration)
        var lines: [String]

        if isRetained {
            lines = ["\(heading) is retained: \(retentionReasons(of: declaration))"]
            guard chain.count > 1 else { return lines.joined(separator: "\n") }

            lines.append("  used through the reference chain:")
        } else {
            lines = ["\(heading) is used, through the reference chain:"]
        }

        for (index, link) in chain.enumerated() {
            lines.append("    \(index + 1). \(describe(link.declaration)): \(describe(link.predecessor, of: link.declaration))")
        }

        return lines.joined(separator: "\n")
    }

    private func unusedExplanation(of declaration: Declaration, heading: String) -> String {
        let references = graph.references(to: declaration).sorted { $0.location < $1.location }
        let discarded = declaration.usrs
            .flatMap { graph.discardedReferencesByUsr[$0, default: []] }
            .sorted { $0.reference.location < $1.reference.location }

        guard references.isEmpty, discarded.isEmpty else {
            var lines = ["\(heading) is reported as unused: no reference to it is reached from a root"]

            for reference in references {
                lines.append("  - reference at \(describe(reference.location))\(describeParent(of: reference)): \(whyNotReached(reference, to: declaration))")
            }

            for discarded in discarded {
                let reference = discarded.reference
                lines.append("  - reference at \(describe(reference.location))\(describeParent(of: reference)): discarded by \(discarded.mutator), \(discarded.detail)")
            }

            return lines.joined(separator: "\n")
        }

        var lines = ["\(heading) is unused: no reference to it was found"]

        for module in declaration.location.file.modules.sorted() {
            let files = graph.unindexedSourceFilesByModule[module, default: []]
            guard !files.isEmpty else { continue }

            let listed = files.prefix(Self.maximumListedFiles).map { relativize($0.string) }.joined(separator: ", ")
            let more = files.count > Self.maximumListedFiles ? ", ..." : ""
            lines.append("  \(files.count) file(s) of module \(module) have no index data, so their references are unknown: \(listed)\(more)")
        }

        return lines.joined(separator: "\n")
    }

    private func whyNotReached(_ reference: Reference, to declaration: Declaration) -> String {
        guard let parent = reference.parent else { return "not reached from a root" }

        if parent == declaration || parent.ancestralDeclarations.contains(declaration) {
            return "self-reference, written inside the declaration it refers to"
        }

        if graph.usedDeclarations.contains(parent) {
            return "not followed from its used parent"
        }

        return "\(describe(parent)) is itself unused"
    }

    private func describeParent(of reference: Reference) -> String {
        reference.parent.map { " in \(qualifiedName(of: $0))" } ?? ""
    }

    private func unusedAncestor(of declaration: Declaration) -> Declaration? {
        var parent = declaration.parent

        while let current = parent {
            if !graph.usedDeclarations.contains(current) {
                var outermost = current
                var next = current.parent
                while let ancestor = next, !graph.usedDeclarations.contains(ancestor) {
                    outermost = ancestor
                    next = ancestor.parent
                }
                return outermost
            }
            parent = current.parent
        }

        return nil
    }

    private func retentionReasons(of declaration: Declaration) -> String {
        let reasons = graph.retentionReasons[declaration, default: []]
        guard !reasons.isEmpty else { return "reason not recorded" }

        return reasons.map { relativize($0.description) }.joined(separator: "; ")
    }

    // MARK: Reference chains

    private struct Link {
        let declaration: Declaration
        let predecessor: UsePredecessor?
    }

    /// The chain from a root to the declaration, following the predecessors recorded by the used-declaration
    /// traversal.
    private func referenceChain(to declaration: Declaration) -> [Link] {
        var chain: [Link] = []
        var visited: Set<Declaration> = []
        var current: Declaration? = declaration

        while let declaration = current, visited.insert(declaration).inserted {
            let predecessor = graph.usePredecessors[declaration]
            chain.append(Link(declaration: declaration, predecessor: predecessor))

            if case let .reference(_, from: parent) = predecessor {
                current = parent
            } else {
                current = nil
            }
        }

        return chain.reversed()
    }

    private func describe(_ predecessor: UsePredecessor?, of declaration: Declaration) -> String {
        switch predecessor {
        case .retained:
            "retained: \(retentionReasons(of: declaration))"
        case let .rootReference(reference):
            "referenced from top-level code at \(describe(reference.location))"
        case let .reference(reference, from: parent):
            switch reference.kind {
            case .normal:
                "referenced at \(describe(reference.location))"
            case .retained:
                "retained within \(qualifiedName(of: parent)): \(retentionReasons(of: declaration))"
            case .related:
                if parent.parent?.kind == .protocol {
                    "protocol witness of the requirement \(qualifiedName(of: parent))"
                } else {
                    "related to \(qualifiedName(of: parent)) (conformance, inheritance or override) at \(describe(reference.location))"
                }
            }
        case .livePreview:
            "previews a used view"
        case nil:
            "reached without a recorded reference"
        }
    }

    // MARK: Descriptions

    private func describe(_ declaration: Declaration) -> String {
        "\(qualifiedName(of: declaration)) (\(declaration.kind.displayName) at \(describe(declaration.location)))"
    }

    private func qualifiedName(of declaration: Declaration) -> String {
        var names = [declaration.name]
        var parent = declaration.parent

        while let current = parent {
            names.insert(current.name, at: 0)
            parent = current.parent
        }

        return names.joined(separator: ".")
    }

    private func describe(_ location: Location) -> String {
        relativize(location.description)
    }

    /// Paths inside the project root are shown relative to it.
    private func relativize(_ text: String) -> String {
        guard !configuration.projectRoot.isEmpty else { return text }

        let prefix = configuration.projectRoot.lexicallyNormalized().string + "/"
        return text.replacingOccurrences(of: prefix, with: "")
    }
}
