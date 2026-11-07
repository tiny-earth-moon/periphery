import Extensions
import Foundation
import Logger

public struct SwiftVersion {
    static let minimumVersion = "6.1.2"
    /// Versions below this one still work but are deprecated: outskirts 4.0 raises the minimum to it.
    static let deprecatedBelowVersion = "6.2"

    /// The version of the `swift` found on PATH.
    public let version: VersionString
    public let fullVersion: String
    /// The version toolchain workarounds are gated on: the compiler that produced the index store units under
    /// analysis, resolved by ``producingIndexUnits(withProviderVersions:logger:context:)``. It is ``version`` until then.
    public let indexStoreVersion: VersionString

    public init(shell: Shell) throws {
        try self.init(fullVersion: shell.exec(["swift", "-version"]).trimmed)
    }

    init(fullVersion: String) throws {
        self.fullVersion = fullVersion
        version = try SwiftVersionParser.parse(fullVersion)
        indexStoreVersion = version
    }

    private init(_ other: SwiftVersion, indexStoreVersion: VersionString) {
        fullVersion = other.fullVersion
        version = other.version
        self.indexStoreVersion = indexStoreVersion
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

    /// Returns a copy whose ``indexStoreVersion`` is the version of the compiler that produced the given index store
    /// units, from the provider version each unit records (`UnitReader.providerVersion`).
    ///
    /// A unit whose provider version is empty or unparsable counts as produced by the PATH `swift`. When the units
    /// disagree, the oldest version wins: every workaround compensates for a defect of older compilers, so the oldest
    /// producer is the one whose output still needs it. The disagreement is logged at debug level.
    public func producingIndexUnits(withProviderVersions providerVersions: [String], logger: ContextualLogger, context: String) -> SwiftVersion {
        let unitVersions = Set(providerVersions.map { Self.parseProviderVersion($0) ?? version })
        let sortedVersions = unitVersions.sorted { $0.isVersion(lessThan: $1) }
        guard let oldest = sortedVersions.first else { return self }

        if sortedVersions.count > 1 {
            logger.debug("\(context): index store units produced by Swift \(sortedVersions.joined(separator: ", ")), gating toolchain workarounds on the oldest, \(oldest)")
        }

        return SwiftVersion(self, indexStoreVersion: oldest)
    }

    /// Accepts both a bare version (`6.2.3`) and a full compiler version (`Apple Swift version 6.2.3 (...)`).
    static func parseProviderVersion(_ providerVersion: String) -> VersionString? {
        let trimmed = providerVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("Swift version") {
            return try? SwiftVersionParser.parse(trimmed)
        }

        let version = trimmed.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "(" }).first.map(String.init) ?? ""
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty, components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }

        return version
    }
}
