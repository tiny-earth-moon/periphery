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
        var members: [(String, JSONValue)] = []

        if let description = settingDescriptions[setting.key] {
            members.append(("description", .string(description)))
        }

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
        case .int:
            return [("type", .string("integer"))]
        case .path:
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

/// A JSON value whose objects keep the order of their members, so that the schema is generated deterministically.
indirect enum JSONValue {
    case bool(Bool)
    case int(Int)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    /// The value of a setting as it is written in the configuration file, nil when there is none.
    init?(settingValue value: Any) {
        switch value {
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as String:
            self = .string(value)
        case let value as FilePath:
            self = .string(value.string)
        case let value as any RawRepresentable:
            guard let raw = value.rawValue as? String else { return nil }

            self = .string(raw)
        case let value as ReportExcludeEntry:
            guard case let .pattern(pattern) = value else { return nil }

            self = .string(pattern)
        case let values as [Any]:
            self = .array(values.compactMap(JSONValue.init(settingValue:)))
        default:
            return nil
        }
    }

    /// Pretty-printed with two spaces of indentation.
    func serialized(indentation: String = "") -> String {
        let inner = indentation + "  "

        switch self {
        case let .bool(value):
            return value ? "true" : "false"
        case let .int(value):
            return "\(value)"
        case let .string(value):
            return Self.quoted(value)
        case let .array(values):
            guard !values.isEmpty else { return "[]" }

            let items = values.map { inner + $0.serialized(indentation: inner) }
            return "[\n" + items.joined(separator: ",\n") + "\n" + indentation + "]"
        case let .object(members):
            guard !members.isEmpty else { return "{}" }

            let items = members.map { inner + Self.quoted($0.0) + ": " + $0.1.serialized(indentation: inner) }
            return "{\n" + items.joined(separator: ",\n") + "\n" + indentation + "}"
        }
    }

    private static func quoted(_ string: String) -> String {
        var result = "\""

        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default:
                result.unicodeScalars.append(scalar)
            }
        }

        return result + "\""
    }
}
