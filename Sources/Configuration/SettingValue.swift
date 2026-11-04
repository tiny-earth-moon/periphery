import Foundation
import SystemPackage

/// Why a value of the configuration file cannot be used for a setting.
enum SettingValueError: Error, Equatable {
    /// The value has not the expected type. `received` replaces the description of the whole value when a part of it is at fault.
    case wrongType(expected: String, received: String? = nil)
    /// The value is a string that is not one of the allowed ones.
    case invalidValue(received: String, allowed: [String])

    /// Describes a value read from YAML, e.g. `the integer 1`.
    static func describe(_ value: Any) -> String {
        switch value {
        case let value as Bool:
            "the boolean \(value)"
        case let value as Int:
            "the integer \(value)"
        case let value as Double:
            "the number \(value)"
        case let value as String:
            "the string \"\(value)\""
        case is NSNull:
            "null"
        case let value as [Any]:
            if let element = value.first(where: { !($0 is String) }) {
                "a list containing \(describe(element))"
            } else {
                "a list"
            }
        case is [AnyHashable: Any]:
            "a mapping"
        default:
            "a value of type \(type(of: value))"
        }
    }
}

/// A value read from the configuration file for a setting.
struct SettingConversion<Value> {
    let value: Value
    /// Set when the value was accepted although it has not the expected type, completes the warning `'<key>' <remark>`.
    var remark: String?

    init(_ value: Value, remark: String? = nil) {
        self.value = value
        self.remark = remark
    }
}

/// The conversions from the value of a YAML document to the value of a setting, by type.
enum SettingConverter {
    typealias Conversion<Value> = @Sendable (Any) throws(SettingValueError) -> SettingConversion<Value>

    /// Booleans, and the strings `true` and `false` that a quoted value yields.
    static let bool: Conversion<Bool> = { value throws(SettingValueError) in
        if let bool = value as? Bool {
            return SettingConversion(bool)
        }
        if let string = value as? String, let bool = Bool(string.lowercased()) {
            return SettingConversion(bool, remark: "expects a boolean, got \(SettingValueError.describe(value)); treating it as \(bool)")
        }

        throw .wrongType(expected: "a boolean")
    }

    static let int: Conversion<Int> = { value throws(SettingValueError) in
        guard !(value is Bool), let int = value as? Int else {
            throw .wrongType(expected: "an integer")
        }

        return SettingConversion(int)
    }

    /// A list of strings, or a single string taken as a list of one.
    static let stringList: Conversion<[String]> = { value throws(SettingValueError) in
        SettingConversion(try strings(value))
    }

    static let optionalString: Conversion<String?> = { value throws(SettingValueError) in
        guard let string = value as? String else {
            throw .wrongType(expected: "a string")
        }

        return SettingConversion(string)
    }

    static let filePath: Conversion<FilePath?> = { value throws(SettingValueError) in
        guard let string = value as? String else {
            throw .wrongType(expected: "a string")
        }

        return SettingConversion(FilePath(string))
    }

    /// A list of paths, or a single path taken as a list of one.
    static let filePathList: Conversion<[FilePath]> = { value throws(SettingValueError) in
        SettingConversion(try strings(value).map { FilePath($0) })
    }

    static func rawValue<Value: RawRepresentable & CaseIterable & Sendable>(of _: Value.Type) -> Conversion<Value> where Value.RawValue == String {
        let allowed = Value.allCases.map(\.rawValue)

        return { value throws(SettingValueError) in
            guard let string = value as? String else {
                throw .wrongType(expected: "one of \(allowed.joined(separator: ", "))")
            }
            guard let converted = Value(rawValue: string) else {
                throw .invalidValue(received: string, allowed: allowed)
            }

            return SettingConversion(converted)
        }
    }

    // MARK: - Private

    private static func strings(_ value: Any) throws(SettingValueError) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let strings = value as? [String] {
            return strings
        }

        throw .wrongType(expected: "a list of strings")
    }
}
