import Foundation
import SwiftParser
import SystemPackage

/// The git working tree, as far as a fix may touch its files.
public enum WorkingTreeState: Sendable {
    /// Every file may be edited (`--allow-dirty`).
    case ignored
    /// The real path of the top level of the working tree, and the real paths of its files with uncommitted changes,
    /// untracked files included.
    case repository(topLevel: String, uncommitted: Set<String>)
    /// The project is not in a git repository, so changes could not be reverted.
    case notARepository
}

/// When the index store and the scan read each file: a file modified since then may not match the results.
public struct IndexDates: Sendable {
    public let scanStartedAt: Date
    /// When the newest index store unit of each source file was written.
    public let unitDates: [FilePath: Date]

    public init(scanStartedAt: Date, unitDates: [FilePath: Date]) {
        self.scanStartedAt = scanStartedAt
        self.unitDates = unitDates
    }

    func isStale(_ file: FilePath, modifiedAt modified: Date) -> Bool {
        guard modified <= scanStartedAt, let unitDate = unitDates[file] else { return true }

        return modified > unitDate
    }
}

/// Turns results into edits of the original buffers, applying the safety rules.
public struct FixPlanner {
    public let workingTree: WorkingTreeState
    /// Nil skips the check, for buffers that were not indexed.
    public let indexDates: IndexDates?
    public let isIndexExcluded: (FilePath) -> Bool

    public init(workingTree: WorkingTreeState, indexDates: IndexDates?, isIndexExcluded: @escaping (FilePath) -> Bool) {
        self.workingTree = workingTree
        self.indexDates = indexDates
        self.isIndexExcluded = isIndexExcluded
    }

    public func plan(_ targets: [FixTarget]) -> FixPlan {
        var plan = FixPlan()
        let uniqueTargets = Array(Set(targets))
        let targetsByFile = Dictionary(grouping: uniqueTargets, by: \.file)

        for file in targetsByFile.keys.sorted(by: { $0.string < $1.string }) {
            let fileTargets = targetsByFile[file, default: []].sorted { ($0.line, $0.column, $0.rule.rawValue, $0.name) < ($1.line, $1.column, $1.rule.rawValue, $1.name) }
            planFile(file, targets: fileTargets, into: &plan)
        }
        return plan
    }

    // MARK: - Private

    private func planFile(_ file: FilePath, targets: [FixTarget], into plan: inout FixPlan) {
        func skipAll(_ reason: SkipReason) {
            plan.skipped += targets.map { FixPlan.Skip(target: $0, reason: reason) }
        }

        if let reason = fileRefusal(file) {
            return skipAll(reason)
        }
        guard let data = FileManager.default.contents(atPath: file.string) else { return skipAll(.unreadableFile) }

        let bytes = [UInt8](data)
        if GeneratedFile.isGenerated(path: file, contents: bytes) {
            return skipAll(.generatedFile)
        }

        // The edits are offsets of the bytes on disk, so the bytes themselves are parsed: decoding them first would
        // drop a byte order mark and shift every offset.
        let tree = bytes.withUnsafeBufferPointer { Parser.parse(source: $0) }
        guard tree.totalLength.utf8Length == bytes.count else { return skipAll(.unreadableFile) }

        let source = ParsedSource(path: file.string, bytes: bytes, tree: tree)
        let builder = EditBuilder(source: source)
        let ignoredParameterNames = superfluousParameterIgnores(in: targets)

        var editsByOwner: [Int: [SourceEdit]] = [:]
        for (index, target) in targets.enumerated() {
            if target.hasLocationOverride {
                plan.skipped.append(.init(target: target, reason: .locationOverride))
                continue
            }

            let names = ignoredParameterNames[TargetPosition(target)] ?? []
            switch builder.edits(for: target, ignoredParameterNames: names) {
            case let .success(edits):
                editsByOwner[index] = edits
            case let .failure(reason):
                plan.skipped.append(.init(target: target, reason: reason))
            }
        }

        let resolution = EditResolution(editsByOwner)
        for index in editsByOwner.keys.sorted() {
            if resolution.refusedOwners.contains(index) {
                plan.skipped.append(.init(target: targets[index], reason: .overlappingEdit))
            } else {
                plan.applied.append(targets[index])
            }
        }

        let fixed = resolution.apply(to: bytes)
        if fixed != bytes {
            plan.changes.append(.init(path: file, original: bytes, fixed: fixed))
        }
    }

    private func fileRefusal(_ file: FilePath) -> SkipReason? {
        if isIndexExcluded(file) {
            return .indexExcluded
        }
        if GeneratedFile.isGenerated(path: file) {
            return .generatedFile
        }

        var status = stat()
        guard lstat(file.string, &status) == 0 else { return .unreadableFile }

        if (status.st_mode & S_IFMT) == S_IFLNK {
            return .symbolicLink
        }

        if let reason = workingTreeRefusal(file) {
            return reason
        }

        if let indexDates, indexDates.isStale(file, modifiedAt: modificationDate(of: status)) {
            return .changedSinceIndexing
        }
        return nil
    }

    private func modificationDate(of status: stat) -> Date {
        #if os(Linux)
            let time = status.st_mtim
        #else
            let time = status.st_mtimespec
        #endif
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000)
    }

    /// Only the files that git can restore are edited: tracked by the working tree itself, not by a submodule or a
    /// nested repository, and without uncommitted changes.
    private func workingTreeRefusal(_ file: FilePath) -> SkipReason? {
        switch workingTree {
        case .ignored:
            return nil
        case .notARepository:
            return .notInGitRepository
        case let .repository(topLevel, uncommitted):
            let realPath = RealPath.resolve(file.string)
            guard realPath.hasPrefix(topLevel + "/") else { return .outsideRepository }

            let directory = FilePath(realPath).removingLastComponent()
            guard GitWorkingTree.topLevel(of: directory) == topLevel else { return .nestedRepository }

            return uncommitted.contains(realPath) ? .uncommittedChanges : nil
        }
    }

    /// The names of the parameters whose `ignore:parameters` comment is superfluous, by function position.
    private func superfluousParameterIgnores(in targets: [FixTarget]) -> [TargetPosition: Set<String>] {
        targets
            .filter { $0.rule == .superfluousIgnore && $0.kind == .varParameter }
            .reduce(into: [:]) { result, target in
                result[TargetPosition(target), default: []].insert(target.name)
            }
    }
}

private struct TargetPosition: Hashable {
    let line: Int
    let column: Int

    init(_ target: FixTarget) {
        line = target.line
        column = target.column
    }
}

/// The edits of a fix run, and the results that were applied or skipped.
public struct FixPlan {
    public struct Change {
        public let path: FilePath
        public let original: [UInt8]
        public let fixed: [UInt8]
    }

    public struct Skip {
        public let target: FixTarget
        public let reason: SkipReason
    }

    public internal(set) var changes: [Change] = []
    public internal(set) var applied: [FixTarget] = []
    public internal(set) var skipped: [Skip] = []

    /// The unified diff of every change, with paths relative to the given directory.
    public func diff(relativeTo root: FilePath) -> String {
        changes.map { change in
            let path = change.path.relativePath(from: root)
            guard let old = String(bytes: change.original, encoding: .utf8),
                  let new = String(bytes: change.fixed, encoding: .utf8)
            else { return "Binary files a/\(path) and b/\(path) differ\n" }

            return UnifiedDiff.diff(old: old, new: new, oldPath: "a/\(path)", newPath: "b/\(path)")
        }.joined()
    }

    /// A short summary of the applied and skipped results, with the reason of each skip.
    public func summary(relativeTo root: FilePath, applying: Bool) -> String {
        let verb = applying ? "Applied" : "Would apply"
        var lines = ["\(verb) \(applied.count) fix\(applied.count == 1 ? "" : "es") in \(changes.count) file\(changes.count == 1 ? "" : "s"), skipped \(skipped.count)."]

        let sortedSkips = skipped.sorted { ($0.target.file.string, $0.target.line, $0.target.column) < ($1.target.file.string, $1.target.line, $1.target.column) }
        for skip in sortedSkips {
            let target = skip.target
            let location = "\(target.file.relativePath(from: root)):\(target.line):\(target.column)"
            lines.append("  skipped \(target.rule.rawValue) '\(target.name)' at \(location): \(skip.reason)")
        }
        return lines.joined(separator: "\n")
    }
}

public extension FilePath {
    func relativePath(from root: FilePath) -> String {
        let rootString = root.string.hasSuffix("/") ? root.string : root.string + "/"
        return string.hasPrefix(rootString) ? String(string.dropFirst(rootString.count)) : string
    }
}

enum RealPath {
    static func resolve(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }

        defer { free(resolved) }
        return String(cString: resolved)
    }
}
