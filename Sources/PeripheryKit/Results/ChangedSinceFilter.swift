import Configuration
import Extensions
import Foundation
import Logger
import Shared
import SystemPackage

/// Keeps the results in files that changed since a git ref (`--changed-since`), or on the changed lines of those
/// files (`--changed-lines`). The changes are those between the merge base of the ref and `HEAD` and the working
/// tree, so committed, staged, unstaged and untracked changes all count.
public final class ChangedSinceFilter {
    private let configuration: Configuration
    private let shell: Shell
    private let contextualLogger: ContextualLogger

    public required init(configuration: Configuration, shell: Shell, logger: Logger) {
        self.configuration = configuration
        self.shell = shell
        contextualLogger = logger.contextualized(with: "report:changed")
    }

    public func filter(_ results: [ScanResult]) throws -> [ScanResult] {
        guard let ref = configuration.changedSince else { return results }

        let changes = try Changes(ref: ref, projectRoot: configuration.projectRoot, shell: shell, wantsLines: configuration.changedLines)
        contextualLogger.debug("\(changes.files.count) changed files, \(changes.untracked.count) of them untracked")

        return results.filter { result in
            var path = result.declaration.location.file.path
            var line = result.declaration.location.line

            // A declaration with a location override is reported there, so it is matched there.
            if let (overridePath, overrideLine, _) = result.declaration.commentCommands.locationOverride {
                path = overridePath
                line = overrideLine
            }

            let key = Self.canonical(path, relativeTo: configuration.projectRoot)

            guard changes.files.contains(key) else { return false }
            guard configuration.changedLines, !changes.untracked.contains(key) else { return true }

            return changes.lines[key]?.contains { $0.contains(line) } ?? false
        }
    }

    static func parseHunksForTesting(_ patch: String) -> [(file: String, ranges: [Range<Int>])] {
        Changes.parseHunks(patch)
    }

    // MARK: - Private

    fileprivate static func canonical(_ path: FilePath, relativeTo base: FilePath) -> String {
        let absolute = path.isAbsolute ? path : base.appending(path.components)
        return URL(fileURLWithPath: absolute.string).resolvingSymlinksInPath().standardizedFileURL.path
    }

    private struct Changes {
        /// Canonical absolute paths of the added, copied, modified and renamed (new path) files, and untracked files.
        var files: Set<String> = []
        var untracked: Set<String> = []
        var lines: [String: [Range<Int>]] = [:]

        init(ref: String, projectRoot: FilePath, shell: Shell, wantsLines: Bool) throws {
            let git = ["git", "-C", projectRoot.string]

            guard !ref.hasPrefix("-") else {
                throw PeripheryError.unknownGitRef(ref: ref)
            }

            let topLevel: String
            do {
                topLevel = try shell.exec(git + ["rev-parse", "--show-toplevel"]).trimmed
            } catch PeripheryError.shellCommandFailed {
                throw PeripheryError.notInGitWorkTree(path: projectRoot.string)
            }

            let root = FilePath(topLevel)
            let inTree = git + ["-c", "core.quotePath=false"]

            do {
                try shell.exec(git + ["rev-parse", "--verify", "--quiet", "\(ref)^{commit}"])
            } catch PeripheryError.shellCommandFailed {
                throw PeripheryError.unknownGitRef(ref: ref)
            }

            let base = try shell.exec(git + ["merge-base", ref, "HEAD"]).trimmed

            let tracked = try shell.exec(inTree + ["diff", "--name-only", "-z", "--diff-filter=ACMR", base, "--"])
            let others = try shell.exec(inTree + ["ls-files", "--others", "--exclude-standard", "-z", "--full-name", "--", ":/"])

            func canonical(_ relative: Substring) -> String {
                ChangedSinceFilter.canonical(FilePath(String(relative)), relativeTo: root)
            }

            for name in tracked.split(separator: "\0") {
                files.insert(canonical(name))
            }

            for name in others.split(separator: "\0") {
                let key = canonical(name)
                files.insert(key)
                untracked.insert(key)
            }

            if wantsLines {
                let patch = try shell.exec(inTree + ["diff", "-U0", "-M", "--no-color", "--no-ext-diff", "--no-prefix", base, "--"])
                for (file, ranges) in Self.parseHunks(patch) {
                    lines[canonical(Substring(file)), default: []] += ranges
                }
            }
        }

        /// The new-side line ranges of each file in a `git diff -U0 --no-prefix` patch. Pure deletions add no lines.
        static func parseHunks(_ patch: String) -> [(file: String, ranges: [Range<Int>])] {
            var out: [(file: String, ranges: [Range<Int>])] = []
            var current: Int?

            for line in patch.split(separator: "\n", omittingEmptySubsequences: false) {
                if line.hasPrefix("diff --git ") {
                    current = nil
                } else if line.hasPrefix("+++ ") {
                    var name = String(line.dropFirst(4))
                    if name.hasSuffix("\t") {
                        name.removeLast()
                    }
                    if name == "/dev/null" {
                        current = nil
                    } else {
                        out.append((unquote(name), []))
                        current = out.count - 1
                    }
                } else if line.hasPrefix("@@ "), let current, let range = newRange(inHunkHeader: line) {
                    out[current].ranges.append(range)
                }
            }

            return out
        }

        /// The `c,d` of `@@ -a,b +c,d @@`; `d` defaults to 1.
        private static func newRange(inHunkHeader header: Substring) -> Range<Int>? {
            guard let plus = header.split(separator: " ").first(where: { $0.hasPrefix("+") }) else { return nil }

            let parts = plus.dropFirst().split(separator: ",", omittingEmptySubsequences: false)
            guard let start = parts.first.flatMap({ Int($0) }) else { return nil }

            let count = parts.count > 1 ? Int(parts[1]) : 1
            guard let count else { return nil }

            return start ..< (start + count)
        }

        /// Git wraps paths that contain a double quote, a backslash or a control character in double quotes.
        private static func unquote(_ name: String) -> String {
            guard name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 else { return name }

            var bytes: [UInt8] = []
            var iterator = Array(name.utf8.dropFirst().dropLast()).makeIterator()

            while let byte = iterator.next() {
                guard byte == UInt8(ascii: "\\"), let escaped = iterator.next() else {
                    bytes.append(byte)
                    continue
                }

                switch escaped {
                case UInt8(ascii: "n"): bytes.append(10)
                case UInt8(ascii: "t"): bytes.append(9)
                case UInt8(ascii: "0") ... UInt8(ascii: "7"):
                    var value = Int(escaped - UInt8(ascii: "0"))
                    for _ in 0 ..< 2 {
                        if let digit = iterator.next() {
                            value = value * 8 + Int(digit - UInt8(ascii: "0"))
                        }
                    }
                    bytes.append(UInt8(truncatingIfNeeded: value))
                default: bytes.append(escaped)
                }
            }

            return String(bytes: bytes, encoding: .utf8) ?? name
        }
    }
}
