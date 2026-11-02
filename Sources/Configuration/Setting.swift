import Foundation
import SystemPackage

protocol AbstractSetting {
    associatedtype Value

    var key: String { get }
    var hasNonDefaultValue: Bool { get }
    var wrappedValue: Value { get }

    /// Assigns a value read from the configuration file. Returns a warning, completed with the path of the file by the
    /// caller, when the value is not valid. An invalid value is replaced by the default.
    func assign(_ value: Any) -> String?
}

@propertyWrapper public final class Setting<Value: Equatable>: AbstractSetting {
    typealias Converter = SettingConverter.Conversion<Value>

    public let defaultValue: Value
    let key: String

    private let convert: Converter
    private let normalize: (Value) -> Value
    private var value: Value

    init(
        key: String,
        defaultValue: Value,
        normalize: @escaping (Value) -> Value = { $0 },
        convert: @escaping Converter
    ) {
        self.key = key
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

extension Setting where Value: RawRepresentable & CaseIterable, Value.RawValue == String {
    convenience init(key: String, defaultValue: Value) {
        self.init(key: key, defaultValue: defaultValue, convert: SettingConverter.rawValue(of: Value.self))
    }
}
