import Foundation

public struct SPMLiteralMatchRow: Sendable {
    public let titleKey: String
    public let symbol: String

    public static let rows = [
        SPMLiteralMatchRow(titleKey: "mac_literal_field_key", symbol: "star"),
    ]
}

public enum SPMLiteralMatchKeys {
    public static func switchKey(_ isFirst: Bool) -> String {
        switch isFirst {
        case true: "mac_literal_switch_first_key"
        case false: "mac_literal_switch_second_key"
        }
    }

    public static let pair: (String, Int) = ("mac_literal_tuple_key", 1)
}
