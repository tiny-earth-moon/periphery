import Foundation

/// A validator for the subset of JSON Schema (draft-07) keywords the SARIF 2.1.0 schema uses, so that the schema can
/// be checked in without a dependency. Keywords it does not know are ignored, `format` among them.
struct JSONSchemaValidator {
    private let root: [String: Any]

    init(schema: [String: Any]) {
        root = schema
    }

    /// Returns one message per violation, each prefixed with the location of the offending value.
    func validate(_ instance: Any) -> [String] {
        validate(instance, against: root, at: "#")
    }

    private func validate(_ value: Any, against schema: [String: Any], at path: String) -> [String] {
        if let ref = schema["$ref"] as? String {
            guard let target = resolve(ref) else { return ["\(path): unresolved reference \(ref)"] }

            return validate(value, against: target, at: path)
        }

        var errors: [String] = []

        if let type = schema["type"], !matches(value, type: type) {
            return ["\(path): expected type \(type), got \(value)"]
        }

        if let enumeration = schema["enum"] as? [Any], !enumeration.contains(where: { equal($0, value) }) {
            errors.append("\(path): \(value) is not one of \(enumeration)")
        }

        if let const = schema["const"], !equal(const, value) {
            errors.append("\(path): \(value) is not \(const)")
        }

        if let alternatives = schema["anyOf"] as? [[String: Any]],
           !alternatives.contains(where: { validate(value, against: $0, at: path).isEmpty })
        {
            errors.append("\(path): matches none of the anyOf alternatives")
        }

        if let alternatives = schema["oneOf"] as? [[String: Any]] {
            let matching = alternatives.filter { validate(value, against: $0, at: path).isEmpty }.count
            if matching != 1 {
                errors.append("\(path): matches \(matching) of the oneOf alternatives")
            }
        }

        if let string = value as? String, !isNumber(value) {
            if let pattern = schema["pattern"] as? String, string.range(of: pattern, options: .regularExpression) == nil {
                errors.append("\(path): '\(string)' does not match \(pattern)")
            }
        }

        if let number = value as? NSNumber, isNumber(value) {
            if let minimum = (schema["minimum"] as? NSNumber)?.doubleValue, number.doubleValue < minimum {
                errors.append("\(path): \(number) is below \(minimum)")
            }

            if let maximum = (schema["maximum"] as? NSNumber)?.doubleValue, number.doubleValue > maximum {
                errors.append("\(path): \(number) is above \(maximum)")
            }
        }

        if let array = value as? [Any] {
            errors += validateArray(array, against: schema, at: path)
        }

        if let object = value as? [String: Any] {
            errors += validateObject(object, against: schema, at: path)
        }

        return errors
    }

    private func validateArray(_ array: [Any], against schema: [String: Any], at path: String) -> [String] {
        var errors: [String] = []

        if let minItems = schema["minItems"] as? Int, array.count < minItems {
            errors.append("\(path): \(array.count) items, at least \(minItems) expected")
        }

        if schema["uniqueItems"] as? Bool == true {
            for (index, item) in array.enumerated() where array[..<index].contains(where: { equal($0, item) }) {
                errors.append("\(path)/\(index): duplicate item")
            }
        }

        if let items = schema["items"] as? [String: Any] {
            for (index, item) in array.enumerated() {
                errors += validate(item, against: items, at: "\(path)/\(index)")
            }
        }

        return errors
    }

    private func validateObject(_ object: [String: Any], against schema: [String: Any], at path: String) -> [String] {
        var errors: [String] = []
        let properties = schema["properties"] as? [String: Any] ?? [:]

        for key in schema["required"] as? [String] ?? [] where object[key] == nil {
            errors.append("\(path): missing required property '\(key)'")
        }

        for (key, value) in object {
            if let propertySchema = properties[key] as? [String: Any] {
                errors += validate(value, against: propertySchema, at: "\(path)/\(key)")
            } else if let additional = schema["additionalProperties"] as? [String: Any] {
                errors += validate(value, against: additional, at: "\(path)/\(key)")
            } else if schema["additionalProperties"] as? Bool == false {
                errors.append("\(path): unexpected property '\(key)'")
            }
        }

        return errors
    }

    private func resolve(_ ref: String) -> [String: Any]? {
        guard ref.hasPrefix("#/") else { return nil }

        var node: Any = root

        for component in ref.dropFirst(2).split(separator: "/") {
            guard let next = (node as? [String: Any])?[String(component)] else { return nil }

            node = next
        }

        return node as? [String: Any]
    }

    /// JSONSerialization decodes booleans as `NSNumber` on Darwin, where `as? Bool` also accepts 0 and 1, and as
    /// `Bool` on Linux.
    private func isBoolean(_ value: Any) -> Bool {
        #if canImport(Darwin)
            guard let number = value as? NSNumber else { return false }

            return CFGetTypeID(number) == CFBooleanGetTypeID()
        #else
            // `NSNumber` bridges to `Bool` for 0 and 1 on Linux, so only the exact dynamic type counts.
            return type(of: value) == Bool.self
        #endif
    }

    private func isNumber(_ value: Any) -> Bool {
        (value is NSNumber || value is Int || value is Double) && !isBoolean(value)
    }

    private func matches(_ value: Any, type: Any) -> Bool {
        if let types = type as? [String] {
            return types.contains { matches(value, type: $0) }
        }

        switch type as? String {
        case "object": return value is [String: Any]
        case "array": return value is [Any]
        case "string": return value is String
        case "boolean": return isBoolean(value)
        case "null": return value is NSNull
        case "number": return isNumber(value)
        case "integer":
            guard isNumber(value) else { return false }

            if value is Int {
                return true
            }

            let double = (value as? NSNumber)?.doubleValue ?? value as? Double
            return double.map { $0 == $0.rounded() } ?? false
        default: return true
        }
    }

    private func equal(_ lhs: Any, _ rhs: Any) -> Bool {
        (lhs as? NSObject)?.isEqual(rhs as? NSObject) ?? false
    }
}
