import Foundation

/// Recovers a variable's type from its demangled USR, e.g. `Module.Holder.count : Swift.Int`.
enum PropertyTypeDemangler {
    static func type(of usrs: Set<String>) -> String? {
        for usr in usrs.sorted() {
            guard let demangled = LocalizedStringCallResolver.demangle(usr: usr),
                  let separator = demangled.range(of: " : ")
            else { continue }

            let type = String(demangled[separator.upperBound...])
                .replacingOccurrences(of: #"\(([A-Za-z_][A-Za-z0-9_]*) in _[0-9A-F]+\)"#, with: "$1", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !type.isEmpty else { continue }

            return type
        }

        return nil
    }
}
