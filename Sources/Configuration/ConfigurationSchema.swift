import Foundation
import SystemPackage

public extension Configuration {
    /// Where the published JSON Schema of the configuration file lives.
    static let schemaURL = "https://raw.githubusercontent.com/tiny-earth-moon/outskirts/master/outskirts.schema.json"

    /// The comment that points YAML editors (yaml-language-server) at the schema.
    static let schemaComment = "# yaml-language-server: $schema=\(schemaURL)"

    /// The keys of the configuration file, in the order of the schema.
    var settingKeys: [String] {
        settings.map(\.key)
    }

    /// The JSON Schema (draft-07) of the configuration file, one property per key in the order of `settings`.
    func jsonSchema() -> String {
        let properties = settings.map { setting in
            (setting.key, Self.schema(of: setting))
        }

        let schema: JSONValue = .object([
            ("$schema", .string("http://json-schema.org/draft-07/schema#")),
            ("$id", .string(Self.schemaURL)),
            ("title", .string("outskirts configuration")),
            ("description", .string("Configuration file of outskirts: .outskirts.yml, .outskirts.yaml, .periphery.yml or .periphery.yaml.")),
            ("type", .string("object")),
            ("additionalProperties", .bool(false)),
            ("properties", .object(properties)),
            ("definitions", .object([("reportExcludeEntry", Self.reportExcludeEntrySchema)])),
        ])

        return schema.serialized() + "\n"
    }

    // MARK: - Private

    private static func schema(of setting: any AbstractSetting) -> JSONValue {
        var members: [(String, JSONValue)] = [("description", .string(setting.description))]
        members += typeMembers(of: setting.kind)

        if let defaultValue = setting.defaultJSONValue {
            members.append(("default", defaultValue))
        }

        return .object(members)
    }

    private static func typeMembers(of kind: SettingValueKind) -> [(String, JSONValue)] {
        let stringType: JSONValue = .object([("type", .string("string"))])

        switch kind {
        case .bool:
            return [("type", .string("boolean"))]
        case .boolOrStringList:
            return [("type", .array([.string("boolean"), .string("array")])), ("items", stringType)]
        case .int:
            return [("type", .string("integer"))]
        case .string, .path:
            return [("type", .string("string"))]
        case .stringList, .pathList:
            // A single string is read as a list of one.
            return [("type", .array([.string("array"), .string("string")])), ("items", stringType)]
        case let .enumeration(cases):
            return [("type", .string("string")), ("enum", .array(cases.map { .string($0) }))]
        case .reportExclude:
            let entry: JSONValue = .object([("$ref", .string("#/definitions/reportExcludeEntry"))])
            return [("oneOf", .array([entry, .object([("type", .string("array")), ("items", entry)])]))]
        }
    }

    private static let reportExcludeEntrySchema: JSONValue = .object([
        ("oneOf", .array([
            .object([
                ("type", .string("string")),
                ("description", .string("A glob, or '<glob>:kind1,kind2' to exclude only the given result kinds.")),
            ]),
            .object([
                ("type", .string("object")),
                ("description", .string("A glob limited to the given result kinds.")),
                ("properties", .object([
                    ("path", .object([("type", .string("string")), ("description", .string("Source file glob."))])),
                    ("kinds", .object([
                        ("type", .string("array")),
                        ("items", .object([("type", .string("string"))])),
                        ("minItems", .int(1)),
                        ("description", .string("Result kinds, e.g. 'unused.function'.")),
                    ])),
                ])),
                ("required", .array([.string("path"), .string("kinds")])),
                ("additionalProperties", .bool(false)),
            ]),
        ])),
    ])
}
