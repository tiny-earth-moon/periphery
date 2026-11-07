import ArgumentParser
import Foundation
import Shared
import SystemPackage

/// The project root and configuration file options shared by the commands that load the configuration.
struct ProjectLocationOptions: ParsableArguments {
    @Option(help: "Path to the root directory of your project (default: the current directory)", completion: .directory)
    var projectRoot: FilePath?

    @Option(help: "Path to configuration file, relative paths being resolved from '--project-root'. By default outskirts looks for .outskirts.yml (or .periphery.yml) in the project root", completion: .file(extensions: ["yml", "yaml"]))
    var config: FilePath?

    /// Makes the project root the current directory, from which relative paths are resolved, and returns it.
    func changeToProjectRoot() throws -> FilePath {
        let projectRoot = projectRoot ?? FilePath(FileManager.default.currentDirectoryPath)
        if !FileManager.default.changeCurrentDirectoryPath(projectRoot.string) {
            throw PeripheryError.changeCurrentDirectoryFailed(projectRoot)
        }
        return projectRoot
    }
}
