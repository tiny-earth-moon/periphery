import Foundation
import SourceGraph
import SystemPackage
import XcodeProj

public final class XcodeTarget {
    let project: XcodeProject

    private let target: PBXTarget
    private var files: [ProjectFileKind: Set<FilePath>] = [:]
    public private(set) var swiftSourceFiles: Set<FilePath> = []

    required init(project: XcodeProject, target: PBXTarget) {
        self.project = project
        self.target = target
    }

    public var isTestTarget: Bool {
        target.productType?.rawValue.contains("test") ?? false
    }

    public var name: String {
        target.name
    }

    public func identifyFiles() throws {
        let groupFiles = try synchronizedGroupFiles()
        try identifyFiles(in: groupFiles)
        swiftSourceFiles = groupFiles.filter { $0.extension?.lowercased() == "swift" }

        let sourcesBuildPhases = project.xcodeProject.pbxproj.sourcesBuildPhases
        let resourcesBuildPhases = project.xcodeProject.pbxproj.resourcesBuildPhases

        swiftSourceFiles.formUnion(try swiftFiles(in: sourcesBuildPhases))
        try identifyFiles(kind: .xcDataModel, in: sourcesBuildPhases)
        try identifyFiles(kind: .xcMappingModel, in: sourcesBuildPhases)
        try identifyFiles(kind: .interfaceBuilder, in: resourcesBuildPhases)
        try identifyFiles(kind: .xcStrings, in: resourcesBuildPhases)
        try identifyInfoPlistFiles()
    }

    /// Values of the `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` build setting in the target configurations.
    public var globalAccentColorNames: Set<String> {
        let settings = target.buildConfigurationList?.buildConfigurations.map(\.buildSettings) ?? []

        return settings.flatMapSet { buildSettings -> Set<String> in
            switch buildSettings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] {
            case let .string(value): [value]
            case let .array(values): Set(values)
            case nil: []
            }
        }
    }

    public func files(kind: ProjectFileKind) -> Set<FilePath> {
        files[kind, default: []]
    }

    // MARK: - Private

    /// Files of the file system synchronized groups (Xcode 16+) belonging to this target, minus the files the
    /// target is excluded from via `membershipExceptions`.
    private func synchronizedGroupFiles() throws -> Set<FilePath> {
        let sourceRoot = project.sourceRoot.lexicallyNormalized()

        return try (target.fileSystemSynchronizedGroups ?? []).flatMapSet { group in
            guard let stringPath = try group.fullPath(sourceRoot: sourceRoot.string) else { return [] }

            let groupPath = FilePath(stringPath).lexicallyNormalized()
            let exceptions = (group.exceptions ?? [])
                .compactMap { $0 as? PBXFileSystemSynchronizedBuildFileExceptionSet }
                .filter { $0.target === target }
                .flatMap { $0.membershipExceptions ?? [] }
            let excludedPaths = exceptions.mapSet { groupPath.appending($0).lexicallyNormalized() }

            return FilePath.glob(groupPath.appending("**/*").string).filter { path in
                !excludedPaths.contains { path == $0 || path.starts(with: $0) }
            }
        }
    }

    private func swiftFiles(in buildPhases: [PBXBuildPhase]) throws -> Set<FilePath> {
        let sourceRoot = project.sourceRoot.lexicallyNormalized()

        return try buildPhases.filter { target.buildPhases.contains($0) }.flatMapSet {
            try ($0.files ?? []).compactMapSet {
                guard let stringPath = try $0.file?.fullPath(sourceRoot: sourceRoot.string) else { return nil }

                let path = FilePath(stringPath).lexicallyNormalized()
                return path.extension?.lowercased() == "swift" ? path : nil
            }
        }
    }

    private func identifyFiles(kind: ProjectFileKind, in buildPhases: [PBXBuildPhase]) throws {
        let targetPhases = buildPhases.filter { target.buildPhases.contains($0) }
        let sourceRoot = project.sourceRoot.lexicallyNormalized()

        let foundFiles = try targetPhases.flatMapSet {
            try ($0.files ?? []).compactMapSet {
                if let stringPath = try $0.file?.fullPath(sourceRoot: sourceRoot.string) {
                    let path = FilePath(stringPath)
                    if let ext = path.extension, kind.extensions.contains(ext.lowercased()) {
                        return path
                    }
                }

                return nil
            }
        }
        files[kind, default: []].formUnion(foundFiles)
    }

    private func identifyFiles(in paths: Set<FilePath>) throws {
        // Info.plist files are located exclusively through the INFOPLIST_FILE build setting.
        let kinds = ProjectFileKind.allCases.filter { $0 != .infoPlist }

        for path in paths {
            for kind in kinds {
                if let ext = path.extension, kind.extensions.contains(ext.lowercased()) {
                    files[kind, default: []].insert(path)
                }
            }
        }
    }

    private func identifyInfoPlistFiles() throws {
        let configurations = target.buildConfigurationList?.buildConfigurations ?? []
        var paths: Set<FilePath> = []

        for configuration in configurations {
            let settings: [String] = switch configuration.buildSettings["INFOPLIST_FILE"] {
            case let .string(value): [value]
            case let .array(values): values
            case nil: []
            }

            for setting in settings {
                try paths.insert(resolveInfoPlistSetting(setting, buildSettings: buildSettings(of: configuration)))
            }
        }

        files[.infoPlist] = paths
    }

    /// The path of an `INFOPLIST_FILE` setting, with its `$(VAR)` / `${VAR}` references expanded from the target and
    /// project build settings of the configuration, relative to the source root unless absolute.
    func resolveInfoPlistSetting(_ setting: String, buildSettings: [String: String]) throws -> FilePath {
        let settings = derivedBuildSettings.merging(buildSettings) { _, configured in configured }
        let expanded = try expandBuildSettings(in: setting, settings: settings, rawSetting: setting, expanding: [])
        let path = FilePath(expanded)

        return path.isAbsolute ? path.lexicallyNormalized() : project.sourceRoot.lexicallyNormalized().appending(expanded).lexicallyNormalized()
    }

    // MARK: - Build settings

    public enum BuildSettingError: Error, LocalizedError, Equatable {
        case unresolvedVariable(name: String, setting: String)
        case recursiveVariable(name: String, setting: String)

        public var errorDescription: String? {
            switch self {
            case let .unresolvedVariable(name, setting):
                "Cannot resolve the build setting variable '\(name)' in INFOPLIST_FILE '\(setting)'."
            case let .recursiveVariable(name, setting):
                "The build setting variable '\(name)' refers to itself in INFOPLIST_FILE '\(setting)'."
            }
        }
    }

    /// The settings Xcode derives from the project and target.
    private var derivedBuildSettings: [String: String] {
        let sourceRoot = project.sourceRoot.lexicallyNormalized().string
        return [
            "SRCROOT": sourceRoot,
            "SOURCE_ROOT": sourceRoot,
            "PROJECT_DIR": sourceRoot,
            "PROJECT_NAME": project.name,
            "TARGET_NAME": target.name,
        ]
    }

    /// The project configuration's settings of the same name, overridden by the target configuration's.
    private func buildSettings(of configuration: XCBuildConfiguration) -> [String: String] {
        var settings: [String: String] = [:]

        let projectConfiguration = project.xcodeProject.pbxproj.rootObject?.buildConfigurationList?.buildConfigurations
            .first { $0.name == configuration.name }

        for buildSettings in [projectConfiguration?.buildSettings, configuration.buildSettings].compactMap(\.self) {
            for (key, value) in buildSettings {
                switch value {
                case let .string(string): settings[key] = string
                case let .array(values): settings[key] = values.joined(separator: " ")
                }
            }
        }

        return settings
    }

    private func expandBuildSettings(
        in value: String,
        settings: [String: String],
        rawSetting: String,
        expanding: Set<String>
    ) throws -> String {
        var result = ""
        var remainder = Substring(value)

        while let dollar = remainder.firstIndex(of: "$") {
            result += remainder[..<dollar]
            let afterDollar = remainder.index(after: dollar)

            guard afterDollar < remainder.endIndex,
                  let close: Character = ["(": ")", "{": "}"][remainder[afterDollar]],
                  let end = remainder[afterDollar...].firstIndex(of: close)
            else {
                result.append("$")
                remainder = remainder[afterDollar...]
                continue
            }

            let name = String(remainder[remainder.index(after: afterDollar) ..< end])
            guard !expanding.contains(name) else {
                throw BuildSettingError.recursiveVariable(name: name, setting: rawSetting)
            }
            guard let variableValue = settings[name] else {
                throw BuildSettingError.unresolvedVariable(name: name, setting: rawSetting)
            }

            result += try expandBuildSettings(
                in: variableValue,
                settings: settings,
                rawSetting: rawSetting,
                expanding: expanding.union([name])
            )
            remainder = remainder[remainder.index(after: end)...]
        }

        return result + remainder
    }
}

extension XcodeTarget: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(target.name)
    }
}

extension XcodeTarget: Equatable {
    public static func == (lhs: XcodeTarget, rhs: XcodeTarget) -> Bool {
        lhs.name == rhs.name
    }
}
