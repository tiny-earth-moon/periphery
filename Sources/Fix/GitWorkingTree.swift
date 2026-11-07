import Foundation
import SystemPackage

/// Reads the uncommitted files of the git working tree that holds a directory. git is run with an argument array,
/// never through a shell.
public enum GitWorkingTree {
    public static func state(at directory: FilePath) throws -> WorkingTreeState {
        guard let root = topLevel(of: directory),
              let status = try run(["status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames"], in: directory)
        else { return .notARepository }

        let paths = status.split(separator: "\0").compactMap { entry -> String? in
            guard entry.count > 3 else { return nil }

            return RealPath.resolve(root + "/" + entry.dropFirst(3))
        }
        return .repository(topLevel: root, uncommitted: Set(paths))
    }

    /// The real path of the top level of the working tree that holds the directory, nil outside any working tree or
    /// when it cannot be read.
    static func topLevel(of directory: FilePath) -> String? {
        do {
            guard let output = try run(["rev-parse", "--show-toplevel"], in: directory) else { return nil }

            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : RealPath.resolve(path)
        } catch {
            return nil
        }
    }

    // MARK: - Private

    /// The standard output of git, or nil when it exits with a non-zero status.
    private static func run(_ arguments: [String], in directory: FilePath) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", directory.string] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        return String(bytes: data, encoding: .utf8)
    }
}
