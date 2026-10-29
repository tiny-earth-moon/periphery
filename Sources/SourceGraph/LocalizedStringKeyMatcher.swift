import Foundation

/// Matches String Catalog keys against the keys used in source.
///
/// A catalogue key is used when it equals a used key, or when both contain format specifiers and are equal once
/// each specifier is treated as a wildcard. The latter matches interpolated literals, whose specifiers depend on
/// the types of the interpolated values (e.g. `"Hello \(name)"` is used as `Hello %@` and matches `Hello %@` as
/// well as `Hello %lld`).
struct LocalizedStringKeyMatcher {
    private static let specifierPlaceholder: Character = "\u{0}"
    private static let flagCharacters = Set("-+ #0'")
    private static let lengthModifiers = ["hh", "ll", "h", "l", "q", "L", "z", "t", "j"]
    private static let conversionCharacters = Set("@dDiuUxXoOfFeEgGcCsSpaA")

    private let usedKeys: Set<String>
    private let usedFormatSkeletons: Set<String>

    init(usedKeys: Set<String>) {
        self.usedKeys = usedKeys
        usedFormatSkeletons = Set(usedKeys.compactMap(Self.formatSkeleton(of:)))
    }

    func matches(_ key: String) -> Bool {
        if usedKeys.contains(key) {
            return true
        }

        guard !usedFormatSkeletons.isEmpty, let skeleton = Self.formatSkeleton(of: key) else { return false }

        return usedFormatSkeletons.contains(skeleton)
    }

    /// The key with each format specifier replaced by a placeholder, or nil when the key has no specifier.
    static func formatSkeleton(of key: String) -> String? {
        let characters = Array(key)
        var skeleton = ""
        var hasSpecifier = false
        var index = 0

        while index < characters.count {
            let character = characters[index]

            guard character == "%" else {
                skeleton.append(character)
                index += 1
                continue
            }

            if index + 1 < characters.count, characters[index + 1] == "%" {
                skeleton += "%%"
                index += 2
                continue
            }

            if let end = specifierEnd(in: characters, from: index + 1) {
                skeleton.append(specifierPlaceholder)
                hasSpecifier = true
                index = end
            } else {
                skeleton.append(character)
                index += 1
            }
        }

        return hasSpecifier ? skeleton : nil
    }

    // MARK: - Private

    /// The index following a format specifier whose `%` precedes `start`, e.g. `%1$lld`, `%.2f`, `%@`.
    private static func specifierEnd(in characters: [Character], from start: Int) -> Int? {
        var index = start

        // Positional argument: `1$`.
        var digitsEnd = index
        while digitsEnd < characters.count, characters[digitsEnd].isASCII, characters[digitsEnd].isNumber {
            digitsEnd += 1
        }
        if digitsEnd > index, digitsEnd < characters.count, characters[digitsEnd] == "$" {
            index = digitsEnd + 1
        }

        while index < characters.count, flagCharacters.contains(characters[index]) {
            index += 1
        }

        index = skipWidth(in: characters, from: index)

        if index < characters.count, characters[index] == "." {
            index = skipWidth(in: characters, from: index + 1)
        }

        for modifier in lengthModifiers where matches(modifier, in: characters, at: index) {
            index += modifier.count
            break
        }

        guard index < characters.count, conversionCharacters.contains(characters[index]) else { return nil }

        return index + 1
    }

    private static func skipWidth(in characters: [Character], from start: Int) -> Int {
        if start < characters.count, characters[start] == "*" {
            return start + 1
        }

        var index = start
        while index < characters.count, characters[index].isASCII, characters[index].isNumber {
            index += 1
        }
        return index
    }

    private static func matches(_ text: String, in characters: [Character], at index: Int) -> Bool {
        let expected = Array(text)
        guard index + expected.count <= characters.count else { return false }

        return Array(characters[index ..< index + expected.count]) == expected
    }
}
