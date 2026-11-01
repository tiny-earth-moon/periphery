public extension Declaration.Kind {
    /// Every kind identifier: a kind raw value or one of its dotted prefixes, e.g. `function`, `function.method`,
    /// `function.method.instance`.
    static let identifiers: Set<String> = Set(allCases.flatMap { kind -> [String] in
        let components = kind.rawValue.split(separator: ".")
        return (1 ... components.count).map { components.prefix($0).joined(separator: ".") }
    })

    static func isValidIdentifier(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }

    /// Whether `identifier` is equal to, or a dotted prefix of, the raw value of this kind.
    func matches(identifier: String) -> Bool {
        rawValue == identifier || rawValue.hasPrefix("\(identifier).")
    }
}
