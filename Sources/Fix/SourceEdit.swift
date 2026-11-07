/// A replacement of a byte range of the original buffer. Edits are never expressed by re-printing the source.
struct SourceEdit: Hashable {
    let range: Range<Int>
    let replacement: [UInt8]

    init(range: Range<Int>, replacement: String = "") {
        self.range = range
        self.replacement = Array(replacement.utf8)
    }

    /// Whether this edit covers the other one, which then collapses into it. An insertion at either end of the range
    /// is adjacent to it rather than inside it.
    func contains(_ other: Self) -> Bool {
        if other.range.isEmpty {
            return range.lowerBound < other.range.lowerBound && other.range.lowerBound < range.upperBound
        }
        return range.lowerBound <= other.range.lowerBound && other.range.upperBound <= range.upperBound
    }

    func overlaps(_ other: Self) -> Bool {
        if range.isEmpty || other.range.isEmpty {
            return contains(other) || other.contains(self)
        }
        return range.overlaps(other.range)
    }
}

/// The edits of one file, grouped by the result that asked for them.
struct EditResolution {
    /// The edits to apply, sorted by position, none overlapping another.
    let edits: [SourceEdit]
    /// The owners whose edits overlap the edits of another owner without containing them, which are all refused.
    let refusedOwners: Set<Int>

    /// Nested edits collapse into the outer one, identical edits are applied once, and overlapping edits are refused
    /// together with every other edit of their owners.
    init(_ editsByOwner: [Int: [SourceEdit]]) {
        var refused = Set<Int>()

        while true {
            let candidates = editsByOwner
                .filter { !refused.contains($0.key) }
                .flatMap { owner, edits in edits.map { (owner: owner, edit: $0) } }
                .sorted { lhs, rhs in
                    if lhs.edit.range.lowerBound != rhs.edit.range.lowerBound {
                        return lhs.edit.range.lowerBound < rhs.edit.range.lowerBound
                    }
                    return lhs.edit.range.upperBound > rhs.edit.range.upperBound
                }

            var kept: [(owner: Int, edit: SourceEdit)] = []
            var newlyRefused = Set<Int>()

            for candidate in candidates {
                let isCovered = kept.contains { kept in
                    kept.edit == candidate.edit || (kept.edit.range != candidate.edit.range && kept.edit.contains(candidate.edit))
                }
                if isCovered {
                    continue
                }
                if let overlapping = kept.first(where: { $0.edit.overlaps(candidate.edit) }) {
                    newlyRefused.insert(overlapping.owner)
                    newlyRefused.insert(candidate.owner)
                    continue
                }
                kept.append(candidate)
            }

            if newlyRefused.isEmpty {
                edits = kept.map(\.edit)
                refusedOwners = refused
                return
            }
            refused.formUnion(newlyRefused)
        }
    }

    /// The buffer with every edit applied.
    func apply(to bytes: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var cursor = 0

        for edit in edits {
            output.append(contentsOf: bytes[cursor ..< edit.range.lowerBound])
            output.append(contentsOf: edit.replacement)
            cursor = edit.range.upperBound
        }
        output.append(contentsOf: bytes[cursor...])
        return output
    }
}
