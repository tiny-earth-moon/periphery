import Configuration
import Foundation
import Indexer
import IndexStore
import Logger
import Shared
import SystemPackage

private enum GenericConfigKey: String, CodingKey {
    case indexstores, plists, xibs, xcdatamodels, xcmappingmodels, xcstrings, testTargets
}

public final class GenericProjectDriver {
    struct GenericConfig: Decodable {
        let indexstores: Set<String>
        let plists: Set<String>
        let xibs: Set<String>
        let xcdatamodels: Set<String>
        let xcmappingmodels: Set<String>
        let xcstrings: Set<String>
        let testTargets: Set<String>

        /// Only `indexstores` is required, the other keys default to an empty set.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: GenericConfigKey.self)
            indexstores = try container.decode(Set<String>.self, forKey: .indexstores)
            plists = try container.decodeIfPresent(Set<String>.self, forKey: .plists) ?? []
            xibs = try container.decodeIfPresent(Set<String>.self, forKey: .xibs) ?? []
            xcdatamodels = try container.decodeIfPresent(Set<String>.self, forKey: .xcdatamodels) ?? []
            xcmappingmodels = try container.decodeIfPresent(Set<String>.self, forKey: .xcmappingmodels) ?? []
            xcstrings = try container.decodeIfPresent(Set<String>.self, forKey: .xcstrings) ?? []
            testTargets = try container.decodeIfPresent(Set<String>.self, forKey: .testTargets) ?? []
        }

        static func load(from path: FilePath) throws -> GenericConfig {
            guard path.exists else {
                throw PeripheryError.pathDoesNotExist(path: path.string)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let data = try Data(contentsOf: path.url)
            let config: GenericConfig

            do {
                config = try decoder.decode(GenericConfig.self, from: data)
            } catch let error as DecodingError {
                throw PeripheryError.usageError("Invalid generic project config \(path.string): \(error.readableReason(keyName: snakeCased))")
            }

            guard !config.indexstores.isEmpty else {
                throw PeripheryError.usageError("Invalid generic project config \(path.string): 'indexstores' must list at least one index store")
            }

            return config
        }

        /// Shows `testTargets` as it is spelt in the file.
        private static func snakeCased(_ key: String) -> String {
            key.reduce(into: "") { result, character in
                if character.isUppercase {
                    result += "_"
                }

                result += character.lowercased()
            }
        }
    }

    private let indexstorePaths: Set<FilePath>
    private let plistPaths: Set<FilePath>
    private let xibPaths: Set<FilePath>
    private let xcDataModelsPaths: Set<FilePath>
    private let xcMappingModelsPaths: Set<FilePath>
    private let xcStringsPaths: Set<FilePath>
    private let testTargets: Set<String>
    private let configuration: Configuration

    public convenience init(genericProjectConfig: FilePath, configuration: Configuration) throws {
        let config = try GenericConfig.load(from: genericProjectConfig)
        let plistPaths = config.plists.mapSet { FilePath.makeAbsolute($0) }
        let xibPaths = config.xibs.mapSet { FilePath.makeAbsolute($0) }
        let xcDataModelPaths = config.xcdatamodels.mapSet { FilePath.makeAbsolute($0) }
        let xcMappingModelPaths = config.xcmappingmodels.mapSet { FilePath.makeAbsolute($0) }
        let xcStringsPaths = config.xcstrings.mapSet { FilePath.makeAbsolute($0) }
        let indexstorePaths = config.indexstores.mapSet { FilePath.makeAbsolute($0) }

        self.init(
            indexstorePaths: indexstorePaths,
            plistPaths: plistPaths,
            xibPaths: xibPaths,
            xcDataModelsPaths: xcDataModelPaths,
            xcMappingModelsPaths: xcMappingModelPaths,
            xcStringsPaths: xcStringsPaths,
            testTargets: config.testTargets,
            configuration: configuration
        )
    }

    private init(
        indexstorePaths: Set<FilePath>,
        plistPaths: Set<FilePath>,
        xibPaths: Set<FilePath>,
        xcDataModelsPaths: Set<FilePath>,
        xcMappingModelsPaths: Set<FilePath>,
        xcStringsPaths: Set<FilePath>,
        testTargets: Set<String>,
        configuration: Configuration
    ) {
        self.indexstorePaths = indexstorePaths
        self.plistPaths = plistPaths
        self.xibPaths = xibPaths
        self.xcDataModelsPaths = xcDataModelsPaths
        self.xcMappingModelsPaths = xcMappingModelsPaths
        self.xcStringsPaths = xcStringsPaths
        self.testTargets = testTargets
        self.configuration = configuration
    }
}

extension GenericProjectDriver: ProjectDriver {
    public func plan(logger: ContextualLogger) throws -> IndexPlan {
        let excludedTestTargets = configuration.excludeTests ? testTargets : []
        let collector = SourceFileCollector(
            indexStorePaths: Set(configuration.indexStorePath).union(indexstorePaths),
            excludedTestTargets: excludedTestTargets,
            logger: logger,
            configuration: configuration
        )
        let sourceFiles = try collector.collect()

        return IndexPlan(
            sourceFiles: sourceFiles,
            plistPaths: plistPaths,
            xibPaths: xibPaths,
            xcDataModelPaths: xcDataModelsPaths,
            xcMappingModelPaths: xcMappingModelsPaths,
            xcStringsPaths: xcStringsPaths
        )
    }
}
