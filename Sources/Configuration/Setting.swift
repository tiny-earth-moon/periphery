import Foundation
import SystemPackage

protocol AbstractSetting {
    associatedtype Value

    var key: String { get }
    var kind: SettingValueKind { get }
    var hasNonDefaultValue: Bool { get }
    /// The default value as it is written in the configuration file, nil when the setting has none.
    var defaultJSONValue: JSONValue? { get }
    var wrappedValue: Value { get }

    /// Assigns a value read from the configuration file. Returns a warning, completed with the path of the file by the
    /// caller, when the value is not valid. An invalid value is replaced by the default.
    func assign(_ value: Any) -> String?
}

@propertyWrapper public final class Setting<Value: Equatable>: AbstractSetting {
    typealias Converter = SettingConverter.Conversion<Value>

    public let defaultValue: Value
    let key: String
    let kind: SettingValueKind

    private let convert: Converter
    private let normalize: (Value) -> Value
    private var value: Value

    init(
        key: String,
        defaultValue: Value,
        kind: SettingValueKind? = nil,
        normalize: @escaping (Value) -> Value = { $0 },
        convert: @escaping Converter
    ) {
        self.key = key
        self.kind = kind ?? SettingValueKind(inferredFrom: Value.self)
        value = defaultValue
        self.defaultValue = defaultValue
        self.normalize = normalize
        self.convert = convert
    }

    public var wrappedValue: Value {
        get { value }
        set { value = normalize(newValue) }
    }

    public var projectedValue: Setting {
        self
    }

    var hasNonDefaultValue: Bool {
        value != defaultValue
    }

    var defaultJSONValue: JSONValue? {
        JSONValue(settingValue: defaultValue)
    }

    func assign(_ newValue: Any) -> String? {
        do {
            let conversion = try convert(newValue)
            value = normalize(conversion.value)

            return conversion.remark.map { "'\(key)' \($0)" }
        } catch {
            value = defaultValue

            switch error {
            case let .wrongType(expected, received):
                return "'\(key)' expects \(expected), got \(received ?? SettingValueError.describe(newValue))"
            case let .invalidValue(received, allowed):
                return "'\(key)' has invalid value '\(received)' (expected one of \(allowed.joined(separator: ", "))); using default '\(defaultDescription)'"
            }
        }
    }

    // MARK: - Private

    private var defaultDescription: String {
        if let raw = defaultValue as? any RawRepresentable {
            return "\(raw.rawValue)"
        }

        return "\(defaultValue)"
    }
}

extension Setting where Value == Bool {
    convenience init(key: String, defaultValue: Value) {
        self.init(key: key, defaultValue: defaultValue, convert: SettingConverter.bool)
    }
}

extension Setting where Value == Int {
    convenience init(key: String, defaultValue: Value) {
        self.init(key: key, defaultValue: defaultValue, convert: SettingConverter.int)
    }
}

extension Setting where Value == [String] {
    /// - Parameter requireDefaultValues: Whether the default values are kept next to the ones given.
    convenience init(key: String, defaultValue: Value, requireDefaultValues: Bool = false) {
        self.init(
            key: key,
            defaultValue: defaultValue,
            normalize: { requireDefaultValues ? Array(Set($0).union(defaultValue)) : $0 },
            convert: SettingConverter.stringList
        )
    }
}

extension Setting where Value: RawRepresentable & CaseIterable & Sendable, Value.RawValue == String {
    convenience init(key: String, defaultValue: Value) {
        self.init(
            key: key,
            defaultValue: defaultValue,
            kind: .enumeration(Value.allCases.map(\.rawValue)),
            convert: SettingConverter.rawValue(of: Value.self)
        )
    }
}

/// The shape of the value a setting takes in the configuration file, from which the JSON Schema is generated.
enum SettingValueKind: Equatable {
    case bool
    case int
    case stringList
    case path
    case pathList
    /// One of the given strings.
    case enumeration([String])
    /// A glob, `<glob>:kind1,kind2` or `{path, kinds}`, or a list of them.
    case reportExclude

    init(inferredFrom type: Any.Type) {
        if type == Bool.self {
            self = .bool
        } else if type == Int.self {
            self = .int
        } else if type == [String].self {
            self = .stringList
        } else if type == FilePath?.self {
            self = .path
        } else if type == [FilePath].self {
            self = .pathList
        } else if type == [ReportExcludeEntry].self {
            self = .reportExclude
        } else {
            preconditionFailure("No configuration file shape for settings of type \(type), pass a 'kind'")
        }
    }
}
