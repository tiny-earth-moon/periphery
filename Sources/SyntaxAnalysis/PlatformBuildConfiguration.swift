import SwiftIfConfig
import SwiftSyntax

/// The platform part of the build configuration an index unit was compiled for, derived from its target triple.
///
/// Only `os()`, `arch()` and `targetEnvironment()` are answered, and only for names known to the compiler. Every
/// other query (custom flags, `canImport()`, `hasFeature()`, `swift()`, `compiler()`...) cannot be answered from a
/// triple and throws, which makes the evaluation of the enclosing `#if` fail.
public struct PlatformBuildConfiguration: BuildConfiguration, Hashable {
    struct UnsupportedQuery: Error {}

    private static let knownOperatingSystems: Set<String> = [
        "macOS", "OSX", "iOS", "tvOS", "watchOS", "visionOS", "Linux", "Windows", "Android", "FreeBSD", "OpenBSD",
        "WASI", "Haiku", "PS4", "Cygwin", "none",
    ]
    private static let knownArchitectures: Set<String> = [
        "arm", "arm64", "arm64_32", "i386", "x86_64", "powerpc", "powerpc64", "powerpc64le", "s390x", "wasm32",
        "riscv64",
    ]
    private static let knownEnvironments: Set<String> = ["simulator", "macCatalyst"]

    let operatingSystems: Set<String>
    let architecture: String
    let environment: String?

    /// Returns `nil` when the triple describes a platform whose conditions are not known with certainty.
    public init?(triple: String) {
        let components = triple.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 3 || components.count == 4 else { return nil }

        switch components[0] {
        case "arm64", "aarch64": architecture = "arm64"
        case "x86_64": architecture = "x86_64"
        default: return nil
        }

        let osName = String(components[2].prefix { $0.isLetter })
        let environmentName = components.count == 4 ? components[3] : nil
        let isApple = components[1] == "apple"

        switch (isApple, osName, environmentName) {
        case (true, "macosx", nil), (true, "macos", nil):
            operatingSystems = ["macOS", "OSX"]
            environment = nil
        case (true, "ios", "macabi"):
            operatingSystems = ["iOS"]
            environment = "macCatalyst"
        case (true, "ios", _), (true, "tvos", _), (true, "watchos", _), (true, "xros", _), (true, "visionos", _):
            guard environmentName == nil || environmentName == "simulator" else { return nil }

            operatingSystems = [Self.appleOperatingSystem(osName)]
            environment = environmentName
        case (false, "linux", "gnu"), (false, "linux", "musl"):
            operatingSystems = ["Linux"]
            environment = nil
        default:
            return nil
        }
    }

    public func isCustomConditionSet(name _: String) throws -> Bool {
        throw UnsupportedQuery()
    }

    public func hasFeature(name _: String) throws -> Bool {
        throw UnsupportedQuery()
    }

    public func hasAttribute(name _: String) throws -> Bool {
        throw UnsupportedQuery()
    }

    public func canImport(importPath _: [(TokenSyntax, String)], version _: CanImportVersion) throws -> Bool {
        throw UnsupportedQuery()
    }

    public func isActiveTargetOS(name: String) throws -> Bool {
        guard Self.knownOperatingSystems.contains(name) else { throw UnsupportedQuery() }

        return operatingSystems.contains(name)
    }

    public func isActiveTargetArchitecture(name: String) throws -> Bool {
        guard Self.knownArchitectures.contains(name) else { throw UnsupportedQuery() }

        return architecture == name
    }

    public func isActiveTargetEnvironment(name: String) throws -> Bool {
        guard Self.knownEnvironments.contains(name) else { throw UnsupportedQuery() }

        return environment == name
    }

    public func isActiveTargetRuntime(name _: String) throws -> Bool {
        throw UnsupportedQuery()
    }

    public func isActiveTargetPointerAuthentication(name _: String) throws -> Bool {
        throw UnsupportedQuery()
    }

    public func isActiveTargetObjectFormat(name _: String) throws -> Bool {
        throw UnsupportedQuery()
    }

    public var targetPointerBitWidth: Int {
        64
    }

    public var targetAtomicBitWidths: [Int] {
        []
    }

    public var endianness: Endianness {
        .little
    }

    /// Never queried: conditions other than `os()`, `arch()` and `targetEnvironment()` are not evaluated.
    public var languageVersion: VersionTuple {
        VersionTuple(0)
    }

    public var compilerVersion: VersionTuple {
        VersionTuple(0)
    }

    // MARK: - Private

    private static func appleOperatingSystem(_ tripleName: String) -> String {
        switch tripleName {
        case "ios": "iOS"
        case "tvos": "tvOS"
        case "watchos": "watchOS"
        default: "visionOS"
        }
    }
}
