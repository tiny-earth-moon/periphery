import Configuration
import Foundation
import Logger
import Shared

public final class SourceGraphMutatorRunner {
    private let mutators: [SourceGraphMutator.Type] = [
        // Must come before all others as we need to observe all references prior to any mutations.
        UnusedImportMarker.self,

        // Must come before ExtensionReferenceBuilder.
        AccessibilityCascader.self,
        ObjCAccessibleRetainer.self,
        JSExportRetainer.self,
        // Must come before RedundantExplicitPublicAccessibilityMarker, which skips retained declarations.
        LinkageAttributeRetainer.self,
        // Must come before ExtensionReferenceBuilder so that it can detect redundant accessibility on extensions.
        RedundantExplicitPublicAccessibilityMarker.self,
        // Must come before ProtocolConformanceReferenceBuilder, which rewrites related references.
        OpenFinalAccessibilityMarker.self,
        // Must come before ExtensionReferenceBuilder, which moves extension members to the extended type.
        RedundantAccessLevelMarker.self,
        GenericClassAndStructConstructorReferenceBuilder.self,
        // Must come before ProtocolExtensionReferenceBuilder because it removes references
        // from the extension to the protocol, thus making them appear to be unknown.
        ExtensionReferenceBuilder.self,
        // Must come before ProtocolConformanceReferenceBuilder because it removes references to
        // conformed protocols, which CodingKeyEnumReferenceBuilder needs to inspect before removal.
        // It must also come after ExtensionReferenceBuilder as some types may declare conformance
        // to Codable in an extension.
        CodingKeyEnumReferenceBuilder.self,
        ProtobufAPIVersionCheckRetainer.self,
        ProtocolExtensionReferenceBuilder.self,
        ProtocolConformanceReferenceBuilder.self,
        ExternalTypeProtocolConformanceReferenceRemover.self,
        // Must come before ComplexPropertyAccessorReferenceBuilder, which treats accessors that hold references as
        // explicit implementations.
        ObservationMacroReferenceEliminator.self,
        ComplexPropertyAccessorReferenceBuilder.self,
        EnumCaseReferenceBuilder.self,
        DefaultConstructorReferenceBuilder.self,
        StructImplicitInitializerReferenceBuilder.self,
        InheritedImplicitInitializerReferenceBuilder.self,

        DynamicMemberRetainer.self,
        UnusedParameterRetainer.self,
        AssetReferenceRetainer.self,
        LocalizedStringRetainer.self,
        MetalFunctionRetainer.self,
        EntryPointAttributeRetainer.self,
        AttributeRetainer.self,
        AssetCatalogSymbolRetainer.self,
        PubliclyAccessibleRetainer.self,
        XCTestRetainer.self,
        SwiftTestingRetainer.self,
        SwiftUIRetainer.self,
        AppIntentsRetainer.self,
        StringInterpolationAppendInterpolationRetainer.self,
        PropertyWrapperRetainer.self,
        MacroWrappedPropertyReferenceBuilder.self,
        ResultBuilderRetainer.self,
        CodablePropertyRetainer.self,
        EquatableHashablePropertyRetainer.self,
        SynthesizedUseRetainer.self,
        ExternalOverrideRetainer.self,
        PlatformConditionalRetainer.self,

        AncestralReferenceEliminator.self,
        AssignOnlyPropertyReferenceEliminator.self,
        UnassignedOptionalPropertyMarker.self,
        UnconstructedEnumCaseMarker.self,

        UsedDeclarationMarker.self,
        // Must come after UsedDeclarationMarker as it groups the used and unused symbols of each asset.
        AssetCatalogSymbolMarker.self,
        RedundantProtocolMarker.self,
    ]

    private let graph: SourceGraph
    private let logger: ContextualLogger
    private let configuration: Configuration
    private let swiftVersion: SwiftVersion

    public required init(graph: SourceGraph, logger: Logger, configuration: Configuration, swiftVersion: SwiftVersion) {
        self.graph = graph
        self.logger = logger.contextualized(with: "mutator:run")
        self.configuration = configuration
        self.swiftVersion = swiftVersion
    }

    public func perform() throws {
        warnAboutUnscannedRetainedPublicModules()

        for mutator in mutators {
            let elapsed = try Benchmark.measure {
                let interval = logger.beginInterval("mutator:run")
                try mutator.init(graph: graph, configuration: configuration, swiftVersion: swiftVersion).mutate()
                logger.endInterval(interval)
            }
            logger.debug("\(mutator) (\(elapsed)s)")
        }
    }

    // MARK: - Private

    /// A module of `retain_public_modules` that is not scanned, misspelt or excluded, retains nothing.
    private func warnAboutUnscannedRetainedPublicModules() {
        let modules = configuration.retainPublicModules.filter { !graph.isModuleIndexed($0) }
        guard !modules.isEmpty else { return }

        logger.warn("retain_public_modules lists modules that are not scanned, whose public declarations are therefore not retained: \(modules.joined(separator: ", "))")
    }
}
