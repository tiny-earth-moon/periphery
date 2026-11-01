import Foundation
import Logger
import Shared
import SystemPackage
@testable import TestShared
@testable import XcodeSupport
import XCTest

final class XcodeTargetTest: XCTestCase {
    private var project: XcodeProject!

    override func setUp() {
        super.setUp()
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let shell = ShellImpl(logger: logger)
        let xcodebuild = Xcodebuild(shell: shell, logger: logger)
        var loadedProjectPaths: Set<FilePath> = []
        project = try! XcodeProject(
            path: UIKitProjectPath,
            loadedProjectPaths: &loadedProjectPaths,
            xcodebuild: xcodebuild,
            shell: shell,
            logger: logger
        )
    }

    override func tearDown() {
        project = nil
        super.tearDown()
    }

    func testSourceFileInGroupWithoutFolder() throws {
        let target = project.targets.first { $0.name == "UIKitProject" }!
        try target.identifyFiles()

        XCTAssertTrue(target.files(kind: .interfaceBuilder).contains {
            $0.relativeTo(ProjectRootPath).string == "Tests/XcodeTests/UIKitProject/UIKitProject/FileInGroupWithoutFolder.xib"
        })
    }

    func testGlobalAccentColorNames_areReadFromTheBuildSettings() {
        let projectTarget = project.targets.first { $0.name == "UIKitProject" }!
        let testTarget = project.targets.first { $0.name == "UIKitProjectTests" }!

        XCTAssertEqual(projectTarget.globalAccentColorNames, ["AccentColor"])
        XCTAssertEqual(testTarget.globalAccentColorNames, [])
    }

    func testInfoPlistSettingExpandsBuildSettingVariables() throws {
        let target = project.targets.first { $0.name == "UIKitProject" }!
        let settings = ["PLIST_DIR": "${TARGET_NAME}"]
        var warnings: [String] = []

        let path = target.resolveInfoPlistSetting("$(PROJECT_DIR)/$(TARGET_NAME)/Info.plist", buildSettings: settings) { warnings.append($0) }
        let indirect = target.resolveInfoPlistSetting("$(PLIST_DIR)/Info.plist", buildSettings: settings) { warnings.append($0) }

        let expected = project.sourceRoot.lexicallyNormalized().appending("UIKitProject/Info.plist")
        XCTAssertEqual(path, expected)
        XCTAssertEqual(indirect, expected)
        XCTAssertEqual(warnings, [])
    }

    func testInfoPlistSettingWithUnresolvableVariableIsSkippedWithWarning() {
        let target = project.targets.first { $0.name == "UIKitProject" }!
        let settings = ["LOOP": "$(LOOP)"]
        let cases = [
            ("$(XCCONFIG_DIR)/Info.plist", "XCCONFIG_DIR"),
            ("$(TARGET_NAME:c99extidentifier)/Info.plist", "TARGET_NAME:c99extidentifier"),
            ("$(LOOP)/Info.plist", "LOOP"),
        ]

        for (setting, variable) in cases {
            var warnings: [String] = []
            let path = target.resolveInfoPlistSetting(setting, buildSettings: settings) { warnings.append($0) }

            XCTAssertNil(path, setting)
            XCTAssertEqual(warnings.count, 1, setting)
            let warning = warnings.first ?? ""
            XCTAssertTrue(warning.contains("'\(variable)'"), warning)
            XCTAssertTrue(warning.contains("'\(setting)'"), warning)
            XCTAssertTrue(warning.contains("'UIKitProject'"), warning)
        }
    }

    func testIsTestTarget() {
        let projectTarget = project.targets.first { $0.name == "UIKitProject" }!
        let testTarget = project.targets.first { $0.name == "UIKitProjectTests" }!

        XCTAssertFalse(projectTarget.isTestTarget)
        XCTAssertTrue(testTarget.isTestTarget)
    }
}
