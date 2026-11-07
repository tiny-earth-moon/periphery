import Foundation
import Logger
import Shared
import SystemPackage
import Yams

public extension Configuration {
    func asYaml() throws -> String {
        var config: [String: Any?] = [:]

        for setting in settings where setting.hasNonDefaultValue {
            config[setting.key] = setting.wrappedValue
        }

        return try Yams.dump(object: config)
    }

    func save(to path: FilePath = defaultConfigurationFile) throws {
        let data = try (Self.schemaComment + "\n" + asYaml()).data(using: .utf8)
        FileManager.default.createFile(atPath: path.string, contents: data)
    }

    /// Loads the configuration file. A value that is not valid for its setting, and a key that is not a setting, are
    /// reported to `warn` and ignored, an unreadable file or a document that is not a mapping is an error.
    func load(from path: FilePath?, warn: ((String) -> Void)? = nil) throws {
        guard let path = try configurationPath(withUserProvided: path) else { return }

        let encodedYAML = try String(contentsOf: path.url, encoding: .utf8)
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)
        let warn = warn ?? { logger.warn($0) }

        // An empty document is an empty configuration.
        guard let document = try Yams.load(yaml: encodedYAML) else { return }
        guard let yaml = document as? [AnyHashable: Any] else {
            throw PeripheryError.usageError("\(path.string): the configuration must be a mapping of keys to values, got \(SettingValueError.describe(document))")
        }

        let entries = yaml.map { (key: "\($0.key.base)", value: $0.value, isString: $0.key.base is String) }.sorted { $0.key < $1.key }

        if let key = entries.map(\.key).first(where: Self.isRemovedBazelKey) {
            throw PeripheryError.removedBazelOption("'\(key)' in \(path.string)")
        }

        for (key, value, isString) in entries {
            if isString, key == $retainPublic.key, value is [Any] {
                if let message = $retainPublicModules.assign(value, reportedKey: key) {
                    warn("\(path.string): \(message)")
                }
            } else if isString, let setting = settings.first(where: { key == $0.key }) {
                if let message = setting.assign(value) {
                    warn("\(path.string): \(message)")
                }
            } else if isString, let suggestion = closestSettingKey(to: key) {
                warn("\(path.string): invalid key '\(key)' (did you mean '\(suggestion)'?)")
            } else {
                warn("\(path.string): invalid key '\(key)'")
            }
        }
    }

    /// The configuration file to read: the given one, which must exist, or else the first existing default file.
    func configurationPath(withUserProvided path: FilePath?) throws -> FilePath? {
        if let path {
            if !path.exists {
                throw PeripheryError.pathDoesNotExist(path: path.lexicallyNormalized().string)
            }

            return path
        }

        return Self.configurationFileNames.map { FilePath($0) }.first { $0.exists }
    }

    // MARK: - Private

    /// Keys of the Bazel mode, removed in 3.13.0, which are rejected instead of being reported as invalid keys.
    /// The setting key that a misspelt key most likely stands for, if any is close enough.
    private func closestSettingKey(to key: String) -> String? {
        let normalized = key.lowercased().replacingOccurrences(of: "-", with: "_")
        let candidates = settings.map(\.key).sorted()

        if let exact = candidates.first(where: { $0 == normalized }) {
            return exact
        }

        let maxDistance = min(3, max(1, key.count / 4))
        let ranked = candidates.map { (key: $0, distance: Self.editDistance(normalized, $0)) }

        return ranked.filter { $0.distance <= maxDistance }.min { $0.distance < $1.distance }?.key
    }

    /// The Levenshtein distance between two strings.
    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        var previous = Array(0 ... rhs.count)

        for (i, l) in lhs.enumerated() {
            var current = [i + 1]

            for (j, r) in rhs.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (l == r ? 0 : 1)))
            }

            previous = current
        }

        return previous[rhs.count]
    }

    private static func isRemovedBazelKey(_ key: String) -> Bool {
        key == "bazel" || key.hasPrefix("bazel_")
    }
}

// MARK: - Yaml Encoding

extension OutputFormat: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        rawValue.represented()
    }
}

extension FilePath: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        string.represented()
    }
}

extension ColorOption: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        rawValue.represented()
    }
}
