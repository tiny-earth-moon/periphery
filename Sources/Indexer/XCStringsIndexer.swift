import Configuration
import FilenameMatcher
import Logger
import Shared
import SourceGraph
import SystemPackage

final class XCStringsIndexer: Indexer {
    enum XCStringsError: Error, CustomStringConvertible {
        case failedToParse(path: FilePath, underlyingError: Error)

        var description: String {
            switch self {
            case let .failedToParse(path, underlyingError):
                "Could not read or parse String Catalog at \(path.string): \(underlyingError.localizedDescription)"
            }
        }
    }

    private let files: Set<FilePath>
    private let modulesByFile: [FilePath: Set<String>]
    private let graph: SourceGraphMutex
    private let logger: ContextualLogger
    private let configuration: Configuration

    required init(
        files: Set<FilePath>,
        modulesByFile: [FilePath: Set<String>] = [:],
        graph: SourceGraphMutex,
        logger: ContextualLogger,
        configuration: Configuration
    ) {
        self.files = files
        self.modulesByFile = modulesByFile
        self.graph = graph
        self.logger = logger.contextualized(with: "xcstrings")
        self.configuration = configuration
        super.init(configuration: configuration)
    }

    func perform() throws {
        warnAboutUnprefixedRuntimeKeys()

        let (indexedFiles, excludedFiles) = filterIndexExcluded(from: files)
        excludedFiles.forEach { self.logger.debug("Excluding \($0.string)") }

        let catalogMatchers = configuration.localizedStringCatalogExcludeMatchers
        let includedFiles = indexedFiles.filter { path in
            guard catalogMatchers.anyMatch(filename: path.string) else { return true }

            self.logger.debug("Excluding catalog \(path.string)")
            return false
        }

        try JobPool(jobs: Array(includedFiles)).forEach { [graph, logger, modulesByFile, projectRoot = configuration.projectRoot] path in
            let elapsed = try Benchmark.measure {
                do {
                    let keys = try XCStringsParser(path: path).parse()
                    let modules = modulesByFile[path] ?? []
                    if modules.isEmpty {
                        logger.debug("Unknown owning module of \(path.string), keys built at runtime in any module are matched against it")
                    }

                    let sourceFile = SourceFile(path: path, modules: modules)

                    let location = Location(file: sourceFile, line: 1, column: 1)
                    let declarations = keys.map { key in
                        Declaration(
                            name: key,
                            kind: .localizedString,
                            usrs: [SyntheticUsr.localizedString(key, in: path, projectRoot: projectRoot)],
                            location: location
                        )
                    }

                    graph.withLock { $0.add(Set(declarations)) }
                } catch {
                    throw XCStringsError.failedToParse(path: path, underlyingError: error)
                }
            }

            logger.debug("\(path.string) (\(elapsed)s)")
        }
    }

    // MARK: - Private

    /// A key built at runtime without a literal prefix may be any key. By default it retains nothing, and each call
    /// site is reported so that its keys can be declared; with `retain_runtime_localized_keys`, it retains every key
    /// of the catalogues it may be looked up in.
    private func warnAboutUnprefixedRuntimeKeys() {
        let (locations, isGlobal, modules) = graph.withLock { graph in
            (
                graph.unprefixedRuntimeLocalizedStringKeyLocations.sorted(),
                graph.runtimeLocalizedStringKeyPrefixes.contains(""),
                graph.runtimeLocalizedStringKeyPrefixesByModule.filter { $0.value.contains("") }.keys.sorted()
            )
        }

        guard configuration.retainRuntimeLocalizedKeys else {
            for location in locations {
                logger.warn("Localized string key built at runtime without a literal prefix at \(location): the String Catalog keys it looks up cannot be determined and are not retained. Declare them with localized_string_key_patterns, or set retain_runtime_localized_keys to retain every key.")
            }
            return
        }

        if isGlobal {
            logger.warn("A localized string key built at runtime, without a literal prefix and looked up in an unknown bundle, retains every String Catalog key (retain_runtime_localized_keys). Run with --verbose to locate it.")
        } else if !modules.isEmpty {
            logger.warn("Localized string keys built at runtime without a literal prefix retain every String Catalog key of: \(modules.joined(separator: ", ")) (retain_runtime_localized_keys). Run with --verbose to locate them.")
        }
    }
}
