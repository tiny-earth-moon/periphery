import Foundation
import SystemPackage

public enum PeripheryError: Error, LocalizedError, CustomStringConvertible {
    case shellCommandFailed(cmd: [String], status: Int32, output: String)
    case shellOutputEncodingFailed(cmd: [String], encoding: String.Encoding)
    case usageError(String)
    case underlyingError(Error)
    case invalidScheme(name: String, project: String)
    case sourceGraphIntegrityError(message: String)
    case guidedSetupError(message: String)
    case updateCheckError(message: String)
    case xcodebuildNotConfigured
    case pathDoesNotExist(path: String)
    case foundIssues(count: Int)
    case packageError(message: String)
    case swiftVersionParseError(fullVersion: String)
    case swiftVersionUnsupportedError(version: String, minimumVersion: String)
    case jsonDeserializationError(error: Error, json: String)
    case indexStoreNotFound(derivedDataPath: String)
    case indexStoreNotFoundAfterSkippedBuild(tried: [String])
    case spmIndexStoreNotFound(tried: [String])
    case changeCurrentDirectoryFailed(FilePath)
    case noIndexedSourceFiles(fileCount: Int, indexStorePaths: [String])

    public var errorDescription: String? {
        switch self {
        case let .shellCommandFailed(cmd, status, output):
            let joinedCmd = cmd.joined(separator: " ")
            return "Shell command '\(joinedCmd)' returned exit status '\(status)':\n\(output)"
        case let .shellOutputEncodingFailed(cmd, encoding):
            let joinedCmd = cmd.joined(separator: " ")
            return "Shell command '\(joinedCmd)' output encoding to \(encoding) failed."
        case let .usageError(message):
            return message
        case let .underlyingError(error):
            return describe(error)
        case let .invalidScheme(name, project):
            return "Scheme '\(name)' does not exist in '\(project)'."
        case let .sourceGraphIntegrityError(message):
            return message
        case let .guidedSetupError(message):
            return "\(message). Please refer to the documentation for instructions on configuring Periphery manually - https://github.com/tiny-earth-moon/periphery#xcode-integration"
        case let .updateCheckError(message):
            return message
        case .xcodebuildNotConfigured:
            return "Xcode is not configured for command-line use. Please run 'sudo xcode-select -s /Applications/Xcode.app'."
        case let .pathDoesNotExist(path):
            return "No such file or directory: \(path)."
        case let .foundIssues(count):
            return "Found \(count) \(count > 1 ? "issues" : "issue")."
        case let .packageError(message):
            return message
        case let .swiftVersionParseError(fullVersion):
            return "Failed to parse Swift version from: \(fullVersion)"
        case let .swiftVersionUnsupportedError(version, minimumVersion):
            return "This version of Periphery only supports Swift >= \(minimumVersion), you're using \(version)."
        case let .jsonDeserializationError(error, json):
            return "JSON deserialization failed: \(describe(error))\nJSON:\n\(json)"
        case let .indexStoreNotFound(derivedDataPath):
            return "Failed to find index datastore at path: \(derivedDataPath)"
        case let .indexStoreNotFoundAfterSkippedBuild(tried):
            let paths = tried.map { "\n  - \($0)" }.joined()
            return "Failed to locate the index store while '--skip-build' is set. Looked in:\(paths)\nBuild the project first (in Xcode or with 'periphery scan' without '--skip-build'), or pass the location of the index store with '--index-store-path'."
        case let .spmIndexStoreNotFound(tried):
            let paths = tried.map { "\n  - \($0)" }.joined()
            return "Failed to locate the SwiftPM index store. Looked for a 'v5' directory in:\(paths)\nBuild the package first (e.g. 'swift build --build-tests'), or pass the location of the index store with '--index-store-path'."
        case let .changeCurrentDirectoryFailed(path):
            return "Failed to change current directory to: \(path)"
        case let .noIndexedSourceFiles(fileCount, indexStorePaths):
            let paths = indexStorePaths.map { "\n  - \($0)" }.joined()
            return "None of the \(fileCount) source file(s) of the scanned targets have index data, so no results can be reported. Index store(s):\(paths)\nThe index store is probably stale or was produced by a different build; rebuild the project and make sure '--index-store-path' points to its index store."
        }
    }

    public var description: String {
        errorDescription!
    }

    // MARK: - Private

    private func describe(_ error: Error) -> String {
        "(\(type(of: error))) \(String(describing: error))"
    }
}
