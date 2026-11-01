import Foundation
import Logger
import Synchronization

final class ShellProcessStore: Sendable {
    private let processes = Mutex<Set<Process>>([])

    func interruptRunning() {
        processes.withLock { processes in
            for process in processes {
                process.interrupt()
                process.waitUntilExit()
            }
        }
    }

    func add(_ process: Process) {
        processes.withLock { _ = $0.insert(process) }
    }

    func remove(_ process: Process) {
        processes.withLock { _ = $0.remove(process) }
    }
}

public protocol Shell: Sendable {
    @discardableResult
    func exec(_ args: [String]) throws -> String
    func execStatus(_ args: [String]) throws -> Int32
}

public final class ShellImpl: Shell {
    private let logger: ContextualLogger
    private let store: ShellProcessStore
    private let signalSource: DispatchSourceSignal

    public required init(logger: Logger, sigintHandler: @escaping () -> Void = {}) {
        self.logger = logger.contextualized(with: "shell")
        store = ShellProcessStore()

        signal(SIGINT, SIG_IGN)
        signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        signalSource.setEventHandler { [store] in
            sigintHandler()
            store.interruptRunning()
            exit(0)
        }
        signalSource.resume()
    }

    @discardableResult
    public func exec(_ args: [String]) throws -> String {
        let (status, stdout, stderr) = try exec(args)

        if status == 0 {
            return stdout
        }

        throw PeripheryError.shellCommandFailed(
            cmd: args,
            status: status,
            output: [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n").trimmed
        )
    }

    @discardableResult
    public func execStatus(_ args: [String]) throws -> Int32 {
        let (status, _, _) = try exec(args, captureOutput: false)
        return status
    }

    // MARK: - Private

    private func exec(
        _ cmd: [String],
        captureOutput: Bool = true
    ) throws -> (Int32, String, String) {
        guard let executable = cmd.first else {
            throw PeripheryError.executableNotFound(name: "", searchPath: [])
        }

        let process = Process()
        process.executableURL = try Self.executableURL(
            for: executable,
            environment: ProcessInfo.processInfo.environment
        )
        process.arguments = Array(cmd.dropFirst())

        logger.debug(cmd.shellQuoted)
        store.add(process)
        defer { store.remove(process) }

        var stdoutPipe: Pipe?
        var stderrPipe: Pipe?

        if captureOutput {
            stdoutPipe = Pipe()
            stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
        }

        try process.run()

        var standardOutput = ""
        var standardError = ""

        let handles = [stdoutPipe?.fileHandleForReading, stderrPipe?.fileHandleForReading]
        let results = Mutex<[Result<Data?, Error>]>([.success(nil), .success(nil)])
        let reads = DispatchGroup()
        for (index, handle) in handles.enumerated() {
            DispatchQueue.global().async(group: reads) {
                let result = Result { try handle?.readToEnd() }
                results.withLock { $0[index] = result }
            }
        }
        reads.wait()

        process.waitUntilExit()

        if let stdoutData = try results.withLock({ try $0[0].get() }) {
            guard let stdoutStr = String(data: stdoutData, encoding: .utf8)
            else {
                throw PeripheryError.shellOutputEncodingFailed(
                    cmd: cmd,
                    encoding: .utf8
                )
            }

            standardOutput = stdoutStr
        }

        if let stderrData = try results.withLock({ try $0[1].get() }) {
            guard let stderrStr = String(data: stderrData, encoding: .utf8)
            else {
                throw PeripheryError.shellOutputEncodingFailed(
                    cmd: cmd,
                    encoding: .utf8
                )
            }

            standardError = stderrStr
        }

        return (process.terminationStatus, standardOutput, standardError)
    }

    /// Resolves the executable of a command without a shell: a name containing a slash is used as a path,
    /// any other name is looked up in the `PATH` of the given environment.
    static func executableURL(for name: String, environment: [String: String]) throws -> URL {
        if name.contains("/") {
            return URL(fileURLWithPath: name)
        }

        let searchPath = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        for directory in searchPath {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               !isDirectory.boolValue,
               FileManager.default.isExecutableFile(atPath: candidate.path)
            {
                return candidate
            }
        }

        throw PeripheryError.executableNotFound(name: name, searchPath: searchPath)
    }
}

public extension [String] {
    /// A human-readable, shell-quoted rendering of a command, for display only. Commands are never run through a shell.
    var shellQuoted: String {
        map(\.shellQuotedArgument).joined(separator: " ")
    }
}

public extension String {
    /// The string as a single shell word: unchanged if it only contains safe characters, single-quoted otherwise.
    var shellQuotedArgument: String {
        let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@%+=:,./_-")
        if !isEmpty, unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return self
        }
        return "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
