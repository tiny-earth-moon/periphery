import Configuration
import Foundation
import Indexer
import IndexStore
import Logger
import Shared
import SourceGraph
import SystemPackage

public final class SPMProjectDriver {
    private let pkg: SPM.Package
    private let configuration: Configuration
    private let logger: Logger

    public convenience init(configuration: Configuration, shell: Shell, logger: Logger) throws {
        if !configuration.schemes.isEmpty {
            throw PeripheryError.usageError("The --schemes option has no effect with Swift Package Manager projects.")
        }

        let pkg = SPM.Package(configuration: configuration, shell: shell, logger: logger)
        self.init(pkg: pkg, configuration: configuration, logger: logger)
    }

    init(pkg: SPM.Package, configuration: Configuration, logger: Logger) {
        self.pkg = pkg
        self.configuration = configuration
        self.logger = logger
    }
}

extension SPMProjectDriver: ProjectDriver {
    public func build() throws {
        if !configuration.skipBuild {
            if configuration.cleanBuild {
                try pkg.clean()
            }

            if configuration.outputFormat.supportsAuxiliaryOutput {
                let asterisk = logger.colorize("*", .boldGreen)
                logger.info("\(asterisk) Building...")
            }

            try pkg.build(additionalArguments: configuration.buildArguments)
        }
    }

    public func plan(logger: ContextualLogger) throws -> IndexPlan {
        let indexStorePaths: Set<FilePath> = if !configuration.indexStorePath.isEmpty {
            Set(configuration.indexStorePath)
        } else {
            try [pkg.indexStorePath(additionalArguments: configuration.buildArguments)]
        }

        // Load package description once and reuse it
        let description = try pkg.load()

        let excludedTestTargets = configuration.excludeTests ? testTargetNames(from: description) : []
        let collector = SourceFileCollector(
            indexStorePaths: indexStorePaths,
            excludedTestTargets: excludedTestTargets,
            logger: logger,
            configuration: configuration
        )
        let sourceFiles = try collector.collect()
        let xibPaths = projectFiles(of: .interfaceBuilder, from: description)
        let xcDataModelPaths = projectFiles(of: .xcDataModel, from: description)
        let xcStringsPaths = projectFiles(of: .xcStrings, from: description)

        return IndexPlan(
            sourceFiles: sourceFiles,
            xibPaths: xibPaths,
            xcDataModelPaths: xcDataModelPaths,
            xcStringsPaths: xcStringsPaths,
            xcStringsModules: projectFileModules(of: .xcStrings, from: description),
            expectedSourceFiles: expectedSourceFiles(from: description, excluding: excludedTestTargets),
            indexStorePaths: indexStorePaths
        )
    }

    // MARK: - Private

    func expectedSourceFiles(from description: PackageDescription, excluding excludedTargets: Set<String>) -> [String: Set<FilePath>] {
        let excluded = excludedTargets.union(configuration.excludeTargets)
        var result: [String: Set<FilePath>] = [:]

        for target in description.targets where !excluded.contains(target.name) {
            let targetPath = pkg.path.appending(target.path)
            let files = (target.sources ?? [])
                .filter { $0.hasSuffix(".swift") }
                .mapSet { targetPath.appending($0).lexicallyNormalized() }

            if !files.isEmpty {
                result[target.name] = files
            }
        }

        return result
    }

    private func testTargetNames(from description: PackageDescription) -> Set<String> {
        description.targets.filter(\.isTestTarget).mapSet(\.name)
    }

    private func projectFiles(of kind: ProjectFileKind, from description: PackageDescription) -> Set<FilePath> {
        Set(projectFileModules(of: kind, from: description).keys)
    }

    /// The project files of a kind, each with the modules of the targets containing it.
    private func projectFileModules(of kind: ProjectFileKind, from description: PackageDescription) -> [FilePath: Set<String>] {
        var files: [FilePath: Set<String>] = [:]
        let extensions = kind.extensions

        for target in description.targets {
            let targetPath = pkg.path.appending(target.path)
            let module = target.c99name ?? target.name
            var targetFiles: Set<FilePath> = []

            // SwiftPM processes Interface Builder files and Core Data models implicitly, without a `resources:` declaration,
            // and `swift package describe` only lists the declared resources.
            for ext in extensions {
                for file in FilePath.glob("\(targetPath.string)/**/*.\(ext)") {
                    // SwiftPM ignores hidden files and directories, such as `.build` and `.scratch`.
                    let relativeComponents = file.components.dropFirst(targetPath.components.count)
                    guard !relativeComponents.contains(where: { $0.string.hasPrefix(".") }) else { continue }

                    targetFiles.insert(file)
                }
            }

            for resource in target.resources ?? [] {
                // Resource.path is always a single file path
                let resourceFilePath = FilePath(resource.path)
                let resourcePath: FilePath = resourceFilePath.isAbsolute
                    ? resourceFilePath
                    : targetPath.appending(resource.path)

                // Check if the resource path exists and has an extension of this kind
                guard resourcePath.exists else { continue }
                guard let ext = resourcePath.extension?.lowercased(), extensions.contains(ext) else { continue }

                targetFiles.insert(resourcePath.lexicallyNormalized())
            }

            for file in targetFiles {
                files[file, default: []].insert(module)
            }
        }

        return files
    }
}
