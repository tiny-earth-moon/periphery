import Foundation

/// A value passed to an API that describes it through reflection (`print`, `String(describing:)`, string
/// interpolation, `dump`, ...), which reads the stored properties of the value's type without referencing them.
///
/// The value is identified either by the location of a token at which the index store records a reference to its
/// type, constructor or property, or by the name of its type when it is only known from syntax (e.g. a local
/// variable with a type annotation).
public struct SynthesizedUse: Hashable {
    public enum Kind: Hashable {
        /// `print`, `debugPrint`, `String(describing:)`, `String(reflecting:)` and string interpolation, which
        /// reflect structs only, unless the type provides its own description.
        case description
        /// `dump`, which reflects the stored properties of structs and classes.
        case dump
    }

    public let kind: Kind
    public let location: Location?
    public let typeName: String?

    public init(kind: Kind, location: Location) {
        self.kind = kind
        self.location = location
        typeName = nil
    }

    public init(kind: Kind, typeName: String) {
        self.kind = kind
        location = nil
        self.typeName = Self.baseTypeName(typeName)
    }

    /// The nominal type name of a declared type, without optionality, array brackets, generic arguments or module
    /// qualification, e.g. `Thing` for `[Module.Thing]?`.
    public static func baseTypeName(_ typeName: String) -> String {
        var name = typeName.trimmingCharacters(in: .whitespaces)

        while let last = name.last, last == "?" || last == "!" {
            name.removeLast()
        }

        if name.hasPrefix("["), name.hasSuffix("]"), !name.contains(":") {
            return baseTypeName(String(name.dropFirst().dropLast()))
        }

        if let genericStart = name.firstIndex(of: "<") {
            name = String(name[..<genericStart])
        }

        return name.split(separator: ".").last.map(String.init) ?? name
    }
}
