import Configuration
@testable import PeripheryKit
import SystemPackage
import XCTest

class FixtureSourceGraphTestCase: SPMSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        build(projectPath: FixturesProjectPath)
    }

    @discardableResult
    func analyze(
        retainPublic: Bool = false,
        retainPublicModules: [String] = [],
        noRetainSPI: [String] = [],
        retainObjcAccessible: Bool = false,
        retainJsAccessible: Bool = false,
        retainObjcAnnotated: Bool = false,
        disableRedundantPublicAnalysis: Bool = false,
        superfluousIgnoreComments: Bool = true,
        retainCodableProperties: Bool = false,
        retainEncodableProperties: Bool = false,
        retainEquatableProperties: Bool = false,
        retainHashableProperties: Bool = false,
        retainUnusedProtocolFuncParams: Bool = false,
        retainUnusedParametersWithoutDefault: Bool = false,
        retainAssignOnlyProperties: Bool = false,
        retainAssignOnlyPropertyTypes: [String] = [],
        enableUnassignedOptionalAnalysis: Bool = false,
        enableUnconstructedEnumCaseAnalysis: Bool = false,
        externalCodableProtocols: [String] = [],
        additionalFilesToIndex: [FilePath] = [],
        indexExcludedFiles: Set<FilePath> = [],
        xibPaths: Set<FilePath> = [],
        plistPaths: Set<FilePath> = [],
        externalTestCaseClasses: [String] = [],
        retainFiles: [String] = [],
        disablePlatformConditionalRetention: Bool = false,
        platformConditionalRetention: PlatformConditionalRetention = .default,
        retainSynthesizedUses: Bool = false,
        retainAttributes: [String] = [],
        detectUnusedAssetCatalogColors: Bool = false,
        detectUnusedAssetCatalogImages: Bool = false,
        detectUnusedMetalFunctions: Bool = false,
        projectRoot: FilePath? = nil,
        fixtureTests: [String]? = nil,
        testBlock: () throws -> Void
    ) rethrows -> [ScanResult] {
        let configuration = Configuration()
        configuration.retainPublic = retainPublic
        configuration.retainPublicModules = retainPublicModules
        configuration.noRetainSPI = noRetainSPI
        configuration.retainObjcAccessible = retainObjcAccessible
        configuration.retainJsAccessible = retainJsAccessible
        configuration.retainObjcAnnotated = retainObjcAnnotated
        configuration.retainAssignOnlyProperties = retainAssignOnlyProperties
        configuration.disableRedundantPublicAnalysis = disableRedundantPublicAnalysis
        configuration.superfluousIgnoreComments = superfluousIgnoreComments
        configuration.externalCodableProtocols = externalCodableProtocols
        configuration.retainCodableProperties = retainCodableProperties
        configuration.retainEncodableProperties = retainEncodableProperties
        configuration.retainEquatableProperties = retainEquatableProperties
        configuration.retainHashableProperties = retainHashableProperties
        configuration.retainUnusedProtocolFuncParams = retainUnusedProtocolFuncParams
        configuration.retainUnusedParametersWithoutDefault = retainUnusedParametersWithoutDefault
        configuration.retainAssignOnlyPropertyTypes = retainAssignOnlyPropertyTypes
        configuration.enableUnassignedOptionalAnalysis = enableUnassignedOptionalAnalysis
        configuration.enableUnconstructedEnumCaseAnalysis = enableUnconstructedEnumCaseAnalysis
        configuration.externalTestCaseClasses = externalTestCaseClasses
        configuration.retainFiles = retainFiles
        configuration.disablePlatformConditionalRetention = disablePlatformConditionalRetention
        configuration.platformConditionalRetention = platformConditionalRetention
        configuration.retainSynthesizedUses = retainSynthesizedUses
        configuration.retainAttributes = retainAttributes
        configuration.detectUnusedAssetCatalogColors = detectUnusedAssetCatalogColors
        configuration.detectUnusedAssetCatalogImages = detectUnusedAssetCatalogImages
        configuration.detectUnusedMetalFunctions = detectUnusedMetalFunctions

        if let projectRoot {
            configuration.projectRoot = projectRoot
        }

        configuration.buildFilenameMatchers()

        // The fixtures of other tests of the suite, instead of the fixture named after the test.
        let fixturePaths = fixtureTests.map { tests in
            tests.map { testFixturePath.removingLastComponent().appending("\($0).swift") }
        } ?? [testFixturePath]

        for fixturePath in fixturePaths where !fixturePath.exists {
            fatalError("\(fixturePath.string) does not exist")
        }

        Self.index(sourceFiles: fixturePaths + additionalFilesToIndex, indexExcludedSourceFiles: indexExcludedFiles, xibPaths: xibPaths, plistPaths: plistPaths, configuration: configuration)
        try testBlock()
        return Self.results
    }
}
