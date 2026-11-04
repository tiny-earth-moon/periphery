#if os(macOS)
    import Configuration
    import Foundation
    import Logger
    @testable import ProjectDrivers
    import Shared
    import SystemPackage
    @testable import XcodeSupport
    import XCTest

    final class XcodebuildDerivedDataPathTest: XCTestCase {
        private final class RecordingShell: Shell, @unchecked Sendable {
            private(set) var commands: [[String]] = []

            func exec(_ args: [String]) throws -> String {
                commands.append(args)
                return "Xcode 0.0"
            }
        }

        private final class ProjectStub: XcodeProjectlike {
            let path = FilePath("/tmp/Sample/Sample.xcodeproj")
            let targets: Set<XcodeTarget> = []
            let type = "project"
            let sourceRoot = FilePath("/tmp/Sample")

            func schemes(additionalArguments _: [String]) throws -> Set<String> {
                []
            }
        }

        private let logger = Logger(quiet: true, verbose: false, colorMode: .never)

        private func makeXcodebuild() -> (Xcodebuild, RecordingShell) {
            let shell = RecordingShell()
            return (Xcodebuild(shell: shell, logger: logger), shell)
        }

        private func derivedDataPath(
            schemes: [String] = ["SchemeA"],
            buildArguments: [String] = []
        ) throws -> String {
            let (xcodebuild, _) = makeXcodebuild()
            return try xcodebuild.derivedDataPath(for: ProjectStub(), schemes: schemes, buildArguments: buildArguments).string
        }

        func testDerivedDataPathIsIndependentOfSchemeOrder() throws {
            let (xcodebuild, _) = makeXcodebuild()
            let project = ProjectStub()

            let forward = try xcodebuild.derivedDataPath(for: project, schemes: ["SchemeA", "SchemeB", "SchemeC"])
            let reversed = try xcodebuild.derivedDataPath(for: project, schemes: ["SchemeC", "SchemeB", "SchemeA"])
            let shuffled = try xcodebuild.derivedDataPath(for: project, schemes: ["SchemeB", "SchemeC", "SchemeA"])

            XCTAssertEqual(forward, reversed)
            XCTAssertEqual(forward, shuffled)
        }

        func testDerivedDataPathDiffersWhenSchemesDiffer() throws {
            XCTAssertNotEqual(
                try derivedDataPath(schemes: ["SchemeA"]),
                try derivedDataPath(schemes: ["SchemeA", "SchemeB"])
            )
        }

        func testDerivedDataPathDiffersWhenBuildArgumentsDiffer() throws {
            let none = try derivedDataPath()
            let simulator = try derivedDataPath(buildArguments: ["-destination", "generic/platform=iOS Simulator"])
            let device = try derivedDataPath(buildArguments: ["-destination", "generic/platform=iOS"])
            let release = try derivedDataPath(buildArguments: ["-configuration", "Release"])

            XCTAssertEqual(Set([none, simulator, device, release]).count, 4)
        }

        func testDerivedDataPathDependsOnBuildArgumentOrderAndBoundaries() throws {
            XCTAssertNotEqual(
                try derivedDataPath(buildArguments: ["-a", "-b"]),
                try derivedDataPath(buildArguments: ["-b", "-a"])
            )
            XCTAssertNotEqual(
                try derivedDataPath(buildArguments: ["ab", "c"]),
                try derivedDataPath(buildArguments: ["a", "bc"])
            )
        }

        func testDerivedDataPathKeepsExistingNameForEmptyBuildArguments() throws {
            let (xcodebuild, _) = makeXcodebuild()
            let project = ProjectStub()
            let version = try xcodebuild.version().djb2Hex
            let projectHash = project.path.lexicallyNormalized().string.djb2Hex
            let schemesHash = "SchemeA".djb2Hex

            let path = try derivedDataPath()

            let expected = try Constants.cachePath().appending("DerivedData-\(version)-\(projectHash)-\(schemesHash)").string
            XCTAssertEqual(path, expected)
        }

        func testDerivedDataPathIsIndependentOfOutputOptions() throws {
            var plain = Configuration()
            plain.buildArguments = ["-destination", "generic/platform=iOS Simulator"]

            var reporting = Configuration()
            reporting.buildArguments = plain.buildArguments
            reporting.outputFormat = .json
            reporting.baseline = FilePath("/tmp/baseline.json")
            reporting.writeBaseline = FilePath("/tmp/new-baseline.json")
            reporting.strict = true
            reporting.relativeResults = true
            reporting.reportExclude = [.pattern("**/Generated/**")]

            let first = try buildDerivedDataPath(configuration: plain)
            let second = try buildDerivedDataPath(configuration: reporting)

            XCTAssertEqual(first, second)
        }

        private func buildDerivedDataPath(configuration: Configuration) throws -> String {
            let (xcodebuild, shell) = makeXcodebuild()
            let driver = XcodeProjectDriver(
                logger: logger,
                configuration: configuration,
                xcodebuild: xcodebuild,
                project: ProjectStub(),
                schemes: ["SchemeA"]
            )

            try driver.build()

            let command = try XCTUnwrap(shell.commands.last { $0.contains("build-for-testing") })
            let index = try XCTUnwrap(command.firstIndex(of: "-derivedDataPath"))
            return command[index + 1]
        }
    }
#endif
