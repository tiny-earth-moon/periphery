import Foundation
import SystemPackage

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
