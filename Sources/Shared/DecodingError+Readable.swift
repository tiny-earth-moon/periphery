import Foundation

public extension DecodingError {
    /// A one-line reason for a file that does not decode, naming the key at fault, where `Error` prints a dump of the
    /// decoder state. `keyName` renders a key of the coding path, e.g. to show the spelling used in the file.
    func readableReason(keyName: (String) -> String = { $0 }) -> String {
        switch self {
        case let .keyNotFound(key, context):
            return "missing key '\(Self.path(context.codingPath + [key], keyName: keyName))'"
        case let .typeMismatch(type, context), let .valueNotFound(type, context):
            let expected = Self.describe(type)
            let path = Self.path(context.codingPath, keyName: keyName)

            return path.isEmpty ? "the top level must be a JSON object" : "'\(path)' must be \(expected)"
        case let .dataCorrupted(context):
            let reason = context.debugDescription.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let path = Self.path(context.codingPath, keyName: keyName)
            let detail = (context.underlyingError as NSError?)?.localizedDescription

            return [path.isEmpty ? nil : "'\(path)'", reason, detail].compactMap(\.self).joined(separator: ": ")
        @unknown default:
            return localizedDescription
        }
    }

    // MARK: - Private

    private static func path(_ codingPath: [CodingKey], keyName: (String) -> String) -> String {
        codingPath.reduce(into: "") { path, key in
            if let index = key.intValue {
                path += "[\(index)]"
            } else {
                path += path.isEmpty ? keyName(key.stringValue) : ".\(keyName(key.stringValue))"
            }
        }
    }

    private static func describe(_ type: Any.Type) -> String {
        switch type {
        case is [String].Type, is Set<String>.Type:
            "a list of strings"
        case is [Any].Type:
            "a list"
        case is String.Type:
            "a string"
        case is Bool.Type:
            "a boolean"
        case is Int.Type:
            "an integer"
        case is [String: Any].Type:
            "an object"
        default:
            "of type \(type)"
        }
    }
}
