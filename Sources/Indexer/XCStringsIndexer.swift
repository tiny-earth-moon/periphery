import Configuration
import FilenameMatcher
import Logger
import Shared
import SourceGraph
import SystemPackage

final class XCStringsIndexer: Indexer {
    enum XCStringsError: Error {
        case failedToParse(path: FilePath, underlyingError: Error)
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

        try JobPool(jobs: Array(includedFiles)).forEach { [weak self] path in
            guard let self else { return }

            let elapsed = try Benchmark.measure {
                do {
                    let keys = try XCStringsParser(path: path).parse()
                    let modules = self.modulesByFile[path] ?? []
                    if modules.isEmpty {
                        self.logger.debug("Unknown owning module of \(path.string), keys built at runtime in any module are matched against it")
                    }

                    let sourceFile = SourceFile(path: path, modules: modules)

                    let location = Location(file: sourceFile, line: 1, column: 1)
                    let declarations = keys.map { key in
                        Declaration(
                            name: key,
                            kind: .localizedString,
                            usrs: ["xcstrings:\(path.string):\(key)"],
                            location: location
                        )
                    }

                    self.graph.withLock { $0.add(Set(declarations)) }
                } catch {
                    throw XCStringsError.failedToParse(path: path, underlyingError: error)
                }
            }

            logger.debug("\(path.string) (\(elapsed)s)")
        }
    }

    // MARK: - Private

    /// A key built at runtime without a literal prefix retains every key of the catalogues it may be looked up in.
    private func warnAboutUnprefixedRuntimeKeys() {
        let (isGlobal, modules) = graph.withLock { graph in
            (
                graph.runtimeLocalizedStringKeyPrefixes.contains(""),
                graph.runtimeLocalizedStringKeyPrefixesByModule.filter { $0.value.contains("") }.keys.sorted()
            )
        }

        if isGlobal {
            logger.warn("A localized string key built at runtime, without a literal prefix and looked up in an unknown bundle, retains every String Catalog key. Run with --verbose to locate it.")
        } else if !modules.isEmpty {
            logger.warn("Localized string keys built at runtime without a literal prefix retain every String Catalog key of: \(modules.joined(separator: ", ")). Run with --verbose to locate them.")
        }
    }
}
