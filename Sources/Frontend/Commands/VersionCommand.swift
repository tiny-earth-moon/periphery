import ArgumentParser
import Foundation
import Shared

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Display the version of outskirts"
    )

    func run() throws {
        print(PeripheryVersion)
    }
}
