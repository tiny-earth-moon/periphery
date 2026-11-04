import ArgumentParser
import Configuration

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Print the JSON Schema of the configuration file",
        subcommands: [ConfigSchemaCommand.self]
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
