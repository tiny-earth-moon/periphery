import Configuration
import Foundation
import Logger
import Shared
import SourceGraph
import SystemPackage

/// Declares the functions of the `.metal` files under the project root that the host looks up by name, so that
/// the ones no Swift string literal names are reported. The functions of conditionally compiled blocks are known,
/// but never reported.
final class MetalFunctionIndexer: Indexer {
    enum MetalFunctionError: Error, CustomStringConvertible {
        case failedToRead(path: FilePath, underlyingError: Error)

        var description: String {
            switch self {
            case let .failedToRead(path, underlyingError):
                "Could not read Metal source at \(path.string): \(underlyingError.localizedDescription)"
            }
        }
    }

    /// Directories of build products and third-party dependencies, whose functions are not the project's own.
    private static let skippedDirectoryNames: Set<String> = [
        "DerivedData", "SourcePackages", "node_modules", "Pods", "Carthage",
    ]

    private let root: FilePath
    private let graph: SourceGraphMutex
    private let logger: ContextualLogger
    private let configuration: Configuration

    required init(root: FilePath, graph: SourceGraphMutex, logger: ContextualLogger, configuration: Configuration) {
        self.root = root
        self.graph = graph
        self.logger = logger.contextualized(with: "metal")
        self.configuration = configuration
        super.init(configuration: configuration)
    }

    func perform() throws {
        let (files, excludedFiles) = filterIndexExcluded(from: Self.metalFiles(under: root))
        excludedFiles.sorted { $0.string < $1.string }.forEach { self.logger.debug("Excluding \($0.string)") }

        var declarations: Set<Declaration> = []
        var names: Set<String> = []
        var isComplete = !files.isEmpty

        for path in files.sorted(by: { $0.string < $1.string }) {
            let source: String
            do {
                source = try String(contentsOfFile: path.string, encoding: .utf8)
            } catch {
                throw MetalFunctionError.failedToRead(path: path, underlyingError: error)
            }

            let result = MetalFunctionParser.parse(source)
            let sourceFile = SourceFile(path: path, modules: [])

            if result.definesFunctionsInMacros {
                logger.debug("\(path.string) declares functions in macros, Swift literals naming an unknown Metal function are not reported")
                isComplete = false
            }

            for function in result.functions {
                names.insert(function.name)
                guard !function.isConditional else { continue }

                declarations.insert(Declaration(
                    name: function.name,
                    kind: .metalFunction,
                    usrs: [SyntheticUsr.metalFunction(function.name, in: path, projectRoot: configuration.projectRoot)],
                    location: Location(file: sourceFile, line: function.line, column: function.column)
                ))
            }

            logger.debug("\(path.string): \(result.functions.count) functions")
        }

        if files.isEmpty {
            logger.debug("No .metal file under \(root.string)")
        }

        graph.withLock { graph in
            graph.add(declarations)
            graph.addDeclaredMetalFunctionNames(names, isComplete: isComplete)
        }
    }

    // MARK: - Private

    /// Hidden directories, such as `.build` and `.git`, and bundles are not searched.
    static func metalFiles(under root: FilePath) -> Set<FilePath> {
        let url = URL(fileURLWithPath: root.string, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: Set<FilePath> = []

        for case let child as URL in enumerator {
            if skippedDirectoryNames.contains(child.lastPathComponent) || child.pathExtension == "build" {
                enumerator.skipDescendants()
                continue
            }

            if child.pathExtension.lowercased() == "metal" {
                files.insert(FilePath(child.path))
            }
        }

        return files
    }
}
