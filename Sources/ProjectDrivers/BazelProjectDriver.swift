import Configuration
import Foundation
import Logger
import Shared
import SystemPackage

public final class BazelProjectDriver: ProjectDriver {
    public static var isSupported: Bool {
        FilePath("MODULE.bazel").exists || FilePath("WORKSPACE").exists
    }

    private static let topLevelKinds = [
        // rules_apple, iOS
        "ios_app_clip",
        "ios_application",
        "ios_extension",
        "ios_imessage_application",
        "ios_imessage_extension",
        "ios_sticker_pack_extension",
        "ios_ui_test",
        "ios_unit_test",

        // rules_apple, tvOS
        "tvos_application",
        "tvos_extension",
        "tvos_ui_test",
        "tvos_unit_test",

        // rules_apple, watchOS
        "watchos_application",
        "watchos_extension",
        "watchos_ui_test",
        "watchos_unit_test",

        // rules_apple, visionOS
        "visionos_application",
        "visionos_ui_test",
        "visionos_unit_test",

        // rules_apple, macOS
        "macos_application",
        "macos_command_line_application",
        "macos_extension",
        "macos_kernel_extension",
        "macos_quick_look_plugin",
        "macos_spotlight_importer",
        "macos_xpc_service",
        "macos_ui_test",
        "macos_unit_test",

        // rules_swift
        "swift_binary",
        "swift_test",
        "swift_compiler_plugin",
    ]

    private let configuration: Configuration
    private let shell: Shell
    private let logger: Logger
    private let fileManager: FileManager

    /// Name of the repository environment variable through which `@periphery//bazel:generated.bzl`
    /// locates the generated BUILD file.
    static let outputPathEnvironmentVariable = "PERIPHERY_BAZEL_OUTPUT_PATH"

    private lazy var contextLogger: ContextualLogger = logger.contextualized(with: "bazel")

    public required init(
        configuration: Configuration,
        shell: Shell,
        logger: Logger,
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.shell = shell
        self.logger = logger
        self.fileManager = fileManager
    }

    public func build() throws {
        let outputPath = try Self.outputPath()
        try Self.createOutputDirectory(at: outputPath, fileManager: fileManager)

        let configPath = outputPath.appending("periphery.yml")
        configuration.bazel = false // Generic project mode is used for the actual scan.
        try configuration.save(to: configPath)
        contextLogger.debug("Configuration written to \(configPath)")

        let buildPath = outputPath.appending("BUILD.bazel")
        let buildFileContents = try Self.buildFileContents(
            configPath: configPath,
            globalIndexStore: configuration.bazelIndexStore.map { $0.makeAbsolute() },
            targets: queryTargets()
        )

        try buildFileContents.write(to: buildPath.url, atomically: true, encoding: .utf8)
        contextLogger.debug("Build file written to \(buildPath)")

        if configuration.outputFormat.supportsAuxiliaryOutput {
            let asterisk = logger.colorize("*", .boldGreen)
            logger.info("\(asterisk) Building...")
        }

        let status = try shell.execStatus(runArguments(outputPath: outputPath))

        // The actual scan is performed by Bazel.
        exit(status)
    }

    /// Per-user directory holding the generated configuration and BUILD file.
    static func outputPath() throws -> FilePath {
        try Constants.cachePath().appending("bazel")
    }

    static func createOutputDirectory(at path: FilePath, fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: path.url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // The directory may predate this version with wider permissions.
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.string)
    }

    static func buildFileContents(configPath: FilePath, globalIndexStore: FilePath?, targets: [String]) -> String {
        let deps = targets.map { starlarkString("@@\($0)") }.joined(separator: ",\n    ")
        let globalIndexStoreValue = globalIndexStore.map { starlarkString($0.string) } ?? "None"
        return """
        load("@periphery//bazel:rules.bzl", "scan")

        scan(
          name = "scan",
          testonly = True,
          config = \(starlarkString(configPath.string)),
          global_indexstore = \(globalIndexStoreValue),
          deps = [
            \(deps)
          ],
        )
        """
    }

    static func starlarkString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    func runArguments(outputPath: FilePath) -> [String] {
        let checkVisibility = configuration.bazelCheckVisibility ? "true" : "false"
        return [
            "bazel",
            "run",
            "--repo_env=\(Self.outputPathEnvironmentVariable)=\(outputPath.string)",
            "--check_visibility=\(checkVisibility)",
            "--ui_event_filters=-info,-debug,-warning",
        ] + configuration.buildArguments + ["@periphery_generated//:scan"]
    }

    var queryArguments: [String] {
        ["bazel", "query", query]
    }

    // MARK: - Private

    private func queryTargets() throws -> [String] {
        try shell
            .exec(queryArguments)
            .split(separator: "\n")
            .map(String.init)
    }

    private var query: String {
        if let bazelQuery = configuration.bazelQuery {
            return bazelQuery
        }

        let kinds = Self.topLevelKinds.joined(separator: "|")
        let query = "filter('^//.*', kind('(\(kinds)) rule', deps(//...)))"

        if let pattern = configuration.bazelFilter {
            return "filter('\(pattern)', \(query))"
        }

        return query
    }
}
