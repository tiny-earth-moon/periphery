import ArgumentParser
import CStdio
import Foundation
import Shared

/// When stdout is a pipe, enable line buffering so output is flushed after each
/// newline rather than block-buffered, ensuring timely output to the consumer.
var info = stat()
fstat(STDOUT_FILENO, &info)

if (info.st_mode & S_IFMT) == S_IFIFO {
    setlinebuf(periphery_stdout())
    setlinebuf(periphery_stderr())
}

struct OutskirtsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outskirts",
        version: PeripheryVersion,
        subcommands: [
            ScanCommand.self,
            FixCommand.self,
            CheckUpdateCommand.self,
            ClearCacheCommand.self,
            ConfigCommand.self,
            VersionCommand.self,
        ]
    )
}

do {
    var command = try OutskirtsCommand.parseAsRoot()
    try command.run()
} catch {
    OutskirtsCommand.exit(withError: error)
}
