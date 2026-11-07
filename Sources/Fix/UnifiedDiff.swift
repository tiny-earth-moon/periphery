/// A unified diff (`diff -u` format, three lines of context) between two versions of a file.
enum UnifiedDiff {
    static func diff(old: String, new: String, oldPath: String, newPath: String, context: Int = 3) -> String {
        let oldLines = lines(of: old)
        let newLines = lines(of: new)
        let operations = operations(from: oldLines, to: newLines)
        guard operations.contains(where: { $0.kind != .equal }) else { return "" }

        var output = "--- \(oldPath)\n+++ \(newPath)\n"
        for hunk in hunks(of: operations, context: context) {
            output += header(of: hunk)
            for operation in hunk {
                switch operation.kind {
                case .equal: output += line(" ", oldLines[operation.oldIndex])
                case .delete: output += line("-", oldLines[operation.oldIndex])
                case .insert: output += line("+", newLines[operation.newIndex])
                }
            }
        }
        return output
    }

    // MARK: - Private

    private enum OperationKind { case equal, delete, insert }

    private struct Operation {
        let kind: OperationKind
        let oldIndex: Int
        let newIndex: Int
    }

    /// The lines of a text, each with its terminator; the last one has none when the text does not end with a newline.
    private static func lines(of text: String) -> [Substring] {
        var lines: [Substring] = []
        var start = text.startIndex
        for index in text.indices where text[index] == "\n" || text[index] == "\r\n" {
            let end = text.index(after: index)
            lines.append(text[start ..< end])
            start = end
        }
        if start < text.endIndex {
            lines.append(text[start...])
        }
        return lines
    }

    private static func line(_ prefix: String, _ text: Substring) -> String {
        text.hasSuffix("\n") ? prefix + text : prefix + text + "\n\\ No newline at end of file\n"
    }

    private static func operations(from oldLines: [Substring], to newLines: [Substring]) -> [Operation] {
        let difference = newLines.difference(from: oldLines)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in difference {
            switch change {
            case let .remove(offset, _, _): removed.insert(offset)
            case let .insert(offset, _, _): inserted.insert(offset)
            }
        }

        var operations: [Operation] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldLines.count || newIndex < newLines.count {
            if oldIndex < oldLines.count, removed.contains(oldIndex) {
                operations.append(Operation(kind: .delete, oldIndex: oldIndex, newIndex: newIndex))
                oldIndex += 1
            } else if newIndex < newLines.count, inserted.contains(newIndex) {
                operations.append(Operation(kind: .insert, oldIndex: oldIndex, newIndex: newIndex))
                newIndex += 1
            } else {
                operations.append(Operation(kind: .equal, oldIndex: oldIndex, newIndex: newIndex))
                oldIndex += 1
                newIndex += 1
            }
        }
        return operations
    }

    private static func hunks(of operations: [Operation], context: Int) -> [ArraySlice<Operation>] {
        let changed = operations.indices.filter { operations[$0].kind != .equal }
        var hunks: [ArraySlice<Operation>] = []
        var start = max(0, changed[0] - context)
        var end = min(operations.count, changed[0] + context + 1)

        for index in changed.dropFirst() {
            if index - context <= end {
                end = min(operations.count, index + context + 1)
            } else {
                hunks.append(operations[start ..< end])
                start = index - context
                end = min(operations.count, index + context + 1)
            }
        }
        hunks.append(operations[start ..< end])
        return hunks
    }

    private static func header(of hunk: ArraySlice<Operation>) -> String {
        let oldCount = hunk.count { $0.kind != .insert }
        let newCount = hunk.count { $0.kind != .delete }
        let first = hunk[hunk.startIndex]
        let oldStart = oldCount == 0 ? first.oldIndex : first.oldIndex + 1
        let newStart = newCount == 0 ? first.newIndex : first.newIndex + 1
        return "@@ -\(range(oldStart, oldCount)) +\(range(newStart, newCount)) @@\n"
    }

    private static func range(_ start: Int, _ count: Int) -> String {
        count == 1 ? "\(start)" : "\(start),\(count)"
    }
}
