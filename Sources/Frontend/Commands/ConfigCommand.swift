import ArgumentParser
import Configuration

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Check the configuration file, or print its JSON Schema",
        subcommands: [ConfigCheckCommand.self, ConfigSchemaCommand.self]
    )
}

struct ConfigSchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Print the JSON Schema (draft-07) of the configuration file"
    )

    func run() throws {
        print(Configuration().jsonSchema(), terminator: "")
    }
}
