import Extensions
import Foundation

public struct SwiftVersion {
    static let minimumVersion = "6.1.2"
    /// Versions below this one still work but are deprecated: outskirts 4.0 raises the minimum to it.
    static let deprecatedBelowVersion = "6.2"

    public let version: VersionString
    public let fullVersion: String

    public init(shell: Shell) throws {
        try self.init(fullVersion: shell.exec(["swift", "-version"]).trimmed)
    }

    init(fullVersion: String) throws {
        self.fullVersion = fullVersion
        version = try SwiftVersionParser.parse(fullVersion)
    }

    public func validateVersion() throws {
        if version.isVersion(lessThan: Self.minimumVersion) {
            throw PeripheryError.swiftVersionUnsupportedError(
                version: fullVersion,
                minimumVersion: Self.minimumVersion
            )
        }
    }

    /// The one-line warning to print when this version is supported but deprecated, nil otherwise.
    public var deprecationWarning: String? {
        guard version.isVersion(lessThan: Self.deprecatedBelowVersion) else { return nil }

        return "Swift \(version) is deprecated: outskirts 4.0 drops Swift 6.1 support and requires Swift \(Self.deprecatedBelowVersion) (Xcode 26) or later."
    }
}
