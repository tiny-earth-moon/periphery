import Configuration
@testable import PeripheryKit
import SystemPackage
@testable import TestShared
import XCTest

extension RetentionTest {
    func testUnusedGenericParameterOfTypeIsNotReportedByDefault() {
        analyzeGenericParameters(reportUnusedTypeParameters: false)

        XCTAssertEqual(unusedGenericParameters(), [])
    }

    func testUnusedGenericParameterOfTypeIsReportedWithOption() {
        analyzeGenericParameters(reportUnusedTypeParameters: true)

        XCTAssertEqual(unusedGenericParameters(), [
            "FixturePhantomTagged.Tag",
            "FixturePhantomClass.Marker",
            "FixturePhantomEnum.Marker",
            "FixturePhantomActor.Marker",
        ])
    }

    // MARK: - Private

    private var genericParametersFixturePath: FilePath {
        FixturesProjectPath.appending("Sources/RetentionFixtures/testUnusedGenericParameterOfTypeIsNotReportedByDefault.swift")
    }

    private func analyzeGenericParameters(reportUnusedTypeParameters: Bool) {
        let configuration = Configuration()
        configuration.retainPublic = true
        configuration.reportUnusedTypeParameters = reportUnusedTypeParameters
        configuration.buildFilenameMatchers()
        Self.index(sourceFiles: [genericParametersFixturePath], configuration: configuration)
    }

    private func unusedGenericParameters() -> Set<String> {
        Set(Self.results.compactMap { result -> String? in
            guard case .unused = result.annotation,
                  result.declaration.kind == .genericTypeParam,
                  result.declaration.location.file.path == genericParametersFixturePath
            else { return nil }

            return "\(result.declaration.parent?.name ?? "?").\(result.declaration.name)"
        })
    }
}
