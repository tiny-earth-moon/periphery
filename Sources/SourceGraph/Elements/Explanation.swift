/// Why a declaration is retained: the mutator (or indexing step) that retained it, and a detail such as the option
/// or attribute involved. Recorded only when `--explain` is passed.
public struct RetentionReason: Hashable, CustomStringConvertible {
    public let retainer: String
    public let detail: String?

    public init(retainer: String, detail: String? = nil) {
        self.retainer = retainer
        self.detail = detail
    }

    public init(_ retainer: Any.Type, _ detail: String? = nil) {
        self.init(retainer: String(describing: retainer), detail: detail)
    }

    public var description: String {
        detail.map { "\(retainer), \($0)" } ?? retainer
    }
}

/// A reference that a mutator removed from the graph, and why. Recorded only when `--explain` is passed.
public struct DiscardedReference: Hashable {
    public let reference: Reference
    public let mutator: String
    public let detail: String

    public init(reference: Reference, mutator: String, detail: String) {
        self.reference = reference
        self.mutator = mutator
        self.detail = detail
    }
}

/// How the used-declaration traversal first reached a declaration. Recorded only when `--explain` is passed; the
/// traversal is breadth-first in that case, so following the predecessors gives a shortest chain from a root.
public enum UsePredecessor {
    /// A retained declaration, from which the traversal starts.
    case retained
    /// A declaration referenced from top-level code, from which the traversal starts.
    case rootReference(Reference)
    /// A declaration reached through a reference (or related reference) whose parent is the predecessor.
    case reference(Reference, from: Declaration)
    /// A `#Preview` expansion or `PreviewProvider` that previews a used view.
    case livePreview
}

/// A line of a platform conditional block that names a declaration, recorded only when `--explain` is passed.
public struct PlatformConditionalNameSite: Hashable {
    public let file: SourceFile
    public let line: Int
    public let condition: String

    public init(file: SourceFile, line: Int, condition: String) {
        self.file = file
        self.line = line
        self.condition = condition
    }
}
