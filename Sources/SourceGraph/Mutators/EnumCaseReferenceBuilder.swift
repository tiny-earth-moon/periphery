import Configuration
import Foundation
import Shared

/// Builds references to enum cases that are used implicitly:
/// - cases of enums that are raw representable or have a synthesized `Decodable` conformance;
/// - cases of `CaseIterable` enums, from every declaration that uses the synthesized `allCases`.
final class EnumCaseReferenceBuilder: SourceGraphMutator {
    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        for enumDeclaration in graph.declarations(ofKind: .enum) {
            let isCodingKey = graph.inheritedTypeReferences(of: enumDeclaration).contains {
                $0.declarationKind == .protocol && $0.name == "CodingKey"
            }

            if !isCodingKey, isRawRepresentable(enumDeclaration) || hasSynthesizedDecodable(enumDeclaration) {
                for enumCase in enumCases(of: enumDeclaration) {
                    addReference(to: enumCase, from: enumDeclaration)
                }
            }
        }

        retainCasesUsedThroughAllCases()
    }

    // MARK: - Private

    private func enumCases(of enumDeclaration: Declaration) -> [Declaration] {
        enumDeclaration.declarations.filter { $0.kind == .enumelement }
    }

    private func addReference(to enumCase: Declaration, from declaration: Declaration?) {
        for usr in enumCase.usrs {
            let reference = Reference(
                name: enumCase.name,
                kind: .normal,
                declarationKind: .enumelement,
                usr: usr,
                location: enumCase.location
            )

            if let declaration {
                reference.parent = declaration
                graph.add(reference, from: declaration)
            } else {
                graph.addRootReference(reference)
            }
        }
    }

    /// The synthesized `allCases` getter has no declaration in the index, only references to
    /// a USR made of the enum USR followed by the mangled member name. The mangled name is not
    /// stable (it may use word substitutions), so references are matched by name and USR prefix.
    /// The cases are referenced from the declaration using `allCases`, so they are used exactly
    /// when that use is reachable.
    private func retainCasesUsedThroughAllCases() {
        let caseIterableEnums = graph.declarations(ofKind: .enum).filter { enumDeclaration in
            guard !enumDeclaration.declarations.contains(where: { $0.kind == .varStatic && $0.name == "allCases" }) else { return false }

            return graph.inheritedTypeReferences(of: enumDeclaration).contains {
                $0.declarationKind == .protocol && $0.name == "CaseIterable"
            }
        }

        guard !caseIterableEnums.isEmpty else { return }

        let allCasesReferences = graph.allReferences.filter {
            $0.kind == .normal &&
                $0.declarationKind == .varStatic &&
                $0.name == "allCases" &&
                graph.declaration(withUsr: $0.usr) == nil
        }

        for reference in allCasesReferences {
            // A nested type has a USR that extends the USR of its parent, so the longest match wins.
            let matches = caseIterableEnums.compactMap { enumDeclaration -> (Declaration, Int)? in
                guard let usr = enumDeclaration.usrs.filter({ reference.usr.hasPrefix($0) }).max(by: { $0.count < $1.count }) else { return nil }

                return (enumDeclaration, usr.count)
            }

            guard let owner = matches.max(by: { $0.1 < $1.1 })?.0 else { continue }

            for enumCase in enumCases(of: owner) {
                addReference(to: enumCase, from: reference.parent)
            }
        }
    }

    /// An enum with a `Decodable` conformance and no explicit `init(from:)` creates its cases
    /// when decoded, so they are as dynamic as the cases of a raw representable enum.
    private func hasSynthesizedDecodable(_ enumDeclaration: Declaration) -> Bool {
        let decodableTypes = ["Codable", "Decodable"] + configuration.externalCodableProtocols

        let isDecodable = graph.inheritedTypeReferences(of: enumDeclaration).contains {
            [.protocol, .typealias].contains($0.declarationKind) && decodableTypes.contains($0.name)
        }

        guard isDecodable else { return false }

        return !enumDeclaration.declarations.contains { $0.kind == .functionConstructor && $0.name == "init(from:)" }
    }

    func isRawRepresentable(_ enumDeclaration: Declaration) -> Bool {
        // If the enum has a related struct it's very likely to be raw representable,
        // and thus is dynamic in nature.

        if enumDeclaration.related.contains(where: { $0.declarationKind == .struct }) {
            return true
        }

        return graph.inheritedTypeReferences(of: enumDeclaration).contains {
            $0.declarationKind == .protocol && $0.name == "RawRepresentable"
        }
    }
}
