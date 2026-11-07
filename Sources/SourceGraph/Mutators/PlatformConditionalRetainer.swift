import Configuration
import Foundation
import Shared

/// The index store only describes the platform it was built for, so code that is only reachable on another
/// platform appears unused. This retains:
///  - declarations marked `@available(<platform>, unavailable)`, as they exist for other platforms, and
///  - declarations whose name is written inside a platform conditional `#if` block, as the reference may live
///    in a branch that was not compiled.
///
/// With `platform_conditional_retention: auto`, a declaration marked unavailable is not retained when its file was
/// indexed for one of these platforms and for a platform where it is available (see `IndexVariant.cover`).
final class PlatformConditionalRetainer: SourceGraphMutator {
    static let nonReferenceableKinds: Set<Declaration.Kind> = [
        .module, .extension, .extensionClass, .extensionEnum, .extensionProtocol, .extensionStruct,
        .functionConstructor, .functionDestructor, .varParameter, .varLocal, .genericTypeParam,
        .functionAccessorAddress, .functionAccessorDidset, .functionAccessorGetter, .functionAccessorMutableaddress,
        .functionAccessorSetter, .functionAccessorWillset, .functionAccessorRead, .functionAccessorModify,
        .functionAccessorInit,
    ]

    private let graph: SourceGraph
    private let configuration: Configuration

    required init(graph: SourceGraph, configuration: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
        self.configuration = configuration
    }

    func mutate() {
        let retention = configuration.resolvedPlatformConditionalRetention
        guard retention != .off else { return }

        let names = graph.platformConditionalNames

        for decl in graph.allDeclarations {
            let unavailablePlatforms = Self.unavailablePlatforms(of: decl)
            let isCovered = retention == .auto
                && IndexVariant.cover(unavailablePlatforms: unavailablePlatforms, in: decl.location.file.variants)

            if !unavailablePlatforms.isEmpty, !isCovered {
                graph.markRetained(decl, reason: RetentionReason(Self.self, "declared unavailable on a platform with @available"))
                graph.markRetained(decl.descendentDeclarations, reason: RetentionReason(Self.self, "inside \(decl.name), declared unavailable on a platform with @available"))
            } else if !names.isEmpty,
                      !Self.nonReferenceableKinds.contains(decl.kind),
                      names.contains(Self.baseName(of: decl.name))
            {
                graph.markRetained(decl, reason: nameRetentionReason(Self.baseName(of: decl.name)))
            }
        }
    }

    // MARK: - Private

    /// The first place, in file and line order, where the name is written in a platform conditional block.
    private func nameRetentionReason(_ name: String) -> RetentionReason {
        let site = graph.platformConditionalNameSites[name, default: []].min {
            ($0.file.path.string, $0.line) < ($1.file.path.string, $1.line)
        }
        guard let site else {
            return RetentionReason(Self.self, "name '\(name)' written in a platform conditional block")
        }

        return RetentionReason(Self.self, "name '\(name)' written in \(site.condition) at \(site.file.path.string):\(site.line)")
    }

    static func baseName(of declarationName: String) -> String {
        declarationName.prefix { $0 != "(" }.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
    }

    private static func removingStringLiterals(from arguments: String) -> String {
        var result = ""
        var isInsideString = false
        var isEscaped = false

        for character in arguments {
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "\"" {
                isInsideString = true
            } else {
                result.append(character)
            }
        }

        return result
    }

    /// The platforms of the `@available(<platform>, unavailable)` attributes of the declaration.
    static func unavailablePlatforms(of decl: Declaration) -> Set<String> {
        decl.attributes.compactMapSet { attribute -> String? in
            guard attribute.name == "available", let arguments = attribute.arguments else { return nil }

            let parts = Self.removingStringLiterals(from: arguments)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard let platform = parts.first,
                  platform != "*",
                  platform != "swift",
                  !platform.hasSuffix("ApplicationExtension")
            else { return nil }

            return parts.dropFirst().contains("unavailable") ? platform : nil
        }
    }
}
