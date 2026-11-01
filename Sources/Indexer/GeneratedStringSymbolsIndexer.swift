import Configuration
import Foundation
import IndexStore
import Logger
import Shared
import SourceGraph
import SyntaxAnalysis

/// Retains the String Catalog keys referenced through the symbols Xcode 26+ generates for them in
/// `GeneratedStringSymbols_<Table>.swift` (`STRING_CATALOG_GENERATE_SYMBOLS`), e.g. `Text(.settingsTitle)`.
///
/// The generated files are not indexed as source: each generated symbol is mapped to its catalogue key, and the key
/// is used when the symbol is referenced. A referenced `LocalizedStringResource` extension member that is neither
/// generated nor declared in the scanned source (e.g. its generated file was removed) cannot be mapped to a key: it
/// is reported with a warning and retains every key of the catalogues of its module.
///
/// Based on agoodkind/periphery@783b5f8, 9ca12ad and 20f40ce by Alex Goodkind.
final class GeneratedStringSymbolsIndexer {
    private static let localizedStringResourceUsrPrefix = "s:10Foundation23LocalizedStringResourceV"

    private let files: [SourceFile: [IndexUnit]]
    private let graph: SourceGraphMutex
    private let logger: ContextualLogger

    init(files: [SourceFile: [IndexUnit]], graph: SourceGraphMutex, logger: ContextualLogger) {
        self.files = files
        self.graph = graph
        self.logger = logger.contextualized(with: "xcstrings:symbols")
    }

    /// Must run once the Swift sources are indexed, as it relies on their references.
    func perform() throws {
        let keysByUsr = try generatedKeysByUsr()
        logger.debug("Read \(keysByUsr.count) generated localized string symbols from \(files.count) files")

        let unresolvedSymbols: [(usr: String, module: String)] = graph.withLock { graph in
            for (usr, keys) in keysByUsr where !graph.references(to: usr).isEmpty {
                graph.addUsedLocalizedStringKeys(keys)
            }

            return graph.allReferencesByUsr.keys.sorted().compactMap { usr in
                guard keysByUsr[usr] == nil,
                      graph.declaration(withUsr: usr) == nil,
                      let module = Self.extendingModule(ofUsr: usr)
                else { return nil }

                return (usr, module)
            }
        }

        for symbol in unresolvedSymbols {
            retainCatalogues(ofUnresolvedSymbol: symbol.usr, module: symbol.module)
        }
    }

    // MARK: - Private

    private func generatedKeysByUsr() throws -> [String: Set<String>] {
        var keysByUsr: [String: Set<String>] = [:]

        for (file, units) in files {
            let source = try String(contentsOfFile: file.path.string, encoding: .utf8)
            let keysByLine = GeneratedStringSymbols.keys(in: source)

            for unit in units {
                for recordName in unit.unit.recordNames {
                    let record = try RecordReader(indexStore: unit.store, recordName: recordName)

                    record.forEach(occurrence: { occurrence in
                        guard occurrence.roles.contains(.definition),
                              [.staticProperty, .staticMethod].contains(occurrence.symbol.kind),
                              let key = keysByLine[occurrence.location.line]
                        else { return }

                        keysByUsr[occurrence.symbol.usr, default: []].insert(key)
                    })
                }
            }
        }

        return keysByUsr
    }

    private func retainCatalogues(ofUnresolvedSymbol usr: String, module: String) {
        let name = graph.withLock { $0.references(to: usr).map(\.name) }.min() ?? usr
        logger.warn("Cannot map the referenced localized string symbol '\(name)' of \(module) to a String Catalog key (is its GeneratedStringSymbols file missing?), retaining every key of the catalogues of \(module).")
        graph.withLock { $0.addRuntimeLocalizedStringKeyPrefixes([""], modules: [module]) }
    }

    /// The module declaring a `LocalizedStringResource` extension member, from its USR, e.g. `App` in
    /// `s:10Foundation23LocalizedStringResourceV3AppE8settingsACvpZ`. Nil for a member of the type itself.
    static func extendingModule(ofUsr usr: String) -> String? {
        guard usr.hasPrefix(localizedStringResourceUsrPrefix) else { return nil }

        var characters = Substring(usr.dropFirst(localizedStringResourceUsrPrefix.count))
        let digits = characters.prefix { $0.isASCII && $0.isNumber }
        guard let length = Int(digits), length > 0 else { return nil }

        characters = characters.dropFirst(digits.count)
        guard characters.count > length else { return nil }

        let module = characters.prefix(length)
        guard characters.dropFirst(length).first == "E" else { return nil }

        return String(module)
    }
}
