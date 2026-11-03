import Foundation

/// Reads the functions of a Metal Shading Language source that the host looks up by name: the ones qualified with
/// `kernel`, `vertex` or `fragment`, or attributed with `[[kernel]]`, `[[vertex]]`, `[[fragment]]`, `[[visible]]`,
/// `[[stitchable]]`, `[[mesh]]`, `[[object]]` or `[[intersection(...)]]`. The name of a function is the one of its
/// `[[host_name("...")]]` attribute when it has one.
///
/// It is a lightweight reader, not a compiler: it only follows the tokens that lead from a qualifier to the name of
/// the function. Comments and string literals are skipped. Preprocessor directives are not evaluated: the functions of
/// every branch of a conditional block are read and flagged as conditional, and a macro definition holding a function
/// qualifier is flagged, as the functions it declares cannot be read.
struct MetalFunctionParser {
    struct Function: Equatable {
        let name: String
        let line: Int
        let column: Int
        /// Whether the function is declared inside a conditionally compiled block (`#if`, `#ifdef`, `#ifndef`).
        let isConditional: Bool
    }

    struct Result: Equatable {
        /// The qualified functions, once per name, in source order.
        let functions: [Function]
        /// Whether a macro definition holds a function qualifier, so that it may declare functions that are not read.
        let definesFunctionsInMacros: Bool
    }

    static let qualifierKeywords: Set<String> = ["kernel", "vertex", "fragment"]
    static let qualifierAttributes: Set<String> = [
        "kernel", "vertex", "fragment", "visible", "stitchable", "mesh", "object", "intersection",
    ]

    private enum TokenKind: Equatable {
        case identifier(String)
        case attribute(names: [String], hostName: String?)
        case punctuation(UInt8)
    }

    private struct Token {
        let kind: TokenKind
        let line: Int
        let column: Int
        let isConditional: Bool
    }

    private let bytes: [UInt8]
    private var index = 0
    private var line = 1
    private var lineStart = 0
    private var conditionalDepth = 0
    private var definesFunctionsInMacros = false
    private var tokens: [Token] = []

    private init(source: String) {
        bytes = Array(source.utf8)
    }

    static func parse(_ source: String) -> Result {
        var parser = MetalFunctionParser(source: source)
        parser.tokenize()
        return Result(functions: parser.functions(), definesFunctionsInMacros: parser.definesFunctionsInMacros)
    }

    // MARK: - Functions

    private func functions() -> [Function] {
        var functions: [Function] = []
        var names: Set<String> = []
        var isQualified = false
        var hostName: String?
        var candidate: Token?
        var angleDepth = 0
        var parenDepth = 0

        func reset() {
            isQualified = false
            hostName = nil
            candidate = nil
            angleDepth = 0
        }

        for token in tokens {
            switch token.kind {
            case let .identifier(identifier):
                guard parenDepth == 0 else { continue }

                if Self.qualifierKeywords.contains(identifier) {
                    isQualified = true
                    candidate = nil
                    angleDepth = 0
                } else if angleDepth == 0 {
                    candidate = token
                }
            case let .attribute(attributeNames, attributeHostName):
                guard parenDepth == 0 else { continue }

                if attributeNames.contains(where: Self.qualifierAttributes.contains) {
                    isQualified = true
                }
                if let attributeHostName {
                    hostName = attributeHostName
                }
            case let .punctuation(character):
                switch character {
                case UInt8(ascii: "<") where isQualified && parenDepth == 0:
                    angleDepth += 1
                case UInt8(ascii: ">") where isQualified && parenDepth == 0:
                    angleDepth = max(0, angleDepth - 1)
                case UInt8(ascii: "("):
                    if parenDepth == 0, isQualified, angleDepth == 0, let nameToken = candidate,
                       case let .identifier(identifier) = nameToken.kind
                    {
                        let name = hostName ?? identifier
                        if names.insert(name).inserted {
                            functions.append(Function(
                                name: name,
                                line: nameToken.line,
                                column: nameToken.column,
                                isConditional: nameToken.isConditional
                            ))
                        }
                        reset()
                    }
                    parenDepth += 1
                case UInt8(ascii: ")"):
                    parenDepth = max(0, parenDepth - 1)
                case UInt8(ascii: ";"), UInt8(ascii: "{"), UInt8(ascii: "}"):
                    if parenDepth == 0 {
                        reset()
                    }
                default:
                    break
                }
            }
        }

        return functions
    }

    // MARK: - Tokens

    private mutating func tokenize() {
        var atLineStart = true

        while index < bytes.count {
            let byte = bytes[index]

            switch byte {
            case UInt8(ascii: "\n"):
                newLine()
                atLineStart = true
                continue
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\r"):
                index += 1
                continue
            case UInt8(ascii: "/") where peek(1) == UInt8(ascii: "/"):
                skipLineComment()
                continue
            case UInt8(ascii: "/") where peek(1) == UInt8(ascii: "*"):
                skipBlockComment()
                continue
            case UInt8(ascii: "#") where atLineStart:
                readDirective()
                continue
            default:
                break
            }

            atLineStart = false
            let column = index - lineStart + 1

            if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
                _ = readQuoted()
            } else if byte == UInt8(ascii: "["), peek(1) == UInt8(ascii: "[") {
                let line = line
                let (names, hostName) = readAttribute()
                append(.attribute(names: names, hostName: hostName), line: line, column: column)
            } else if Self.isIdentifierStart(byte) {
                append(.identifier(readIdentifier()), line: line, column: column)
            } else if Self.isDigit(byte) {
                while index < bytes.count, Self.isIdentifierPart(bytes[index]) || bytes[index] == UInt8(ascii: ".") {
                    index += 1
                }
            } else {
                append(.punctuation(byte), line: line, column: column)
                index += 1
            }
        }
    }

    private mutating func append(_ kind: TokenKind, line: Int, column: Int) {
        tokens.append(Token(kind: kind, line: line, column: column, isConditional: conditionalDepth > 0))
    }

    private func peek(_ offset: Int) -> UInt8? {
        index + offset < bytes.count ? bytes[index + offset] : nil
    }

    private mutating func newLine() {
        index += 1
        line += 1
        lineStart = index
    }

    private mutating func skipLineComment() {
        while index < bytes.count, bytes[index] != UInt8(ascii: "\n") {
            index += 1
        }
    }

    private mutating func skipBlockComment() {
        index += 2

        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "*"), peek(1) == UInt8(ascii: "/") {
                index += 2
                return
            }

            if bytes[index] == UInt8(ascii: "\n") {
                newLine()
            } else {
                index += 1
            }
        }
    }

    /// Reads a string or character literal, returning its raw contents.
    private mutating func readQuoted() -> String {
        let quote = bytes[index]
        index += 1
        let start = index

        while index < bytes.count, bytes[index] != quote, bytes[index] != UInt8(ascii: "\n") {
            index += bytes[index] == UInt8(ascii: "\\") ? 2 : 1
        }

        let end = min(index, bytes.count)
        if index < bytes.count, bytes[index] == quote {
            index += 1
        }

        return Self.string(bytes[start ..< end])
    }

    private mutating func readIdentifier() -> String {
        let start = index

        while index < bytes.count, Self.isIdentifierPart(bytes[index]) {
            index += 1
        }

        return Self.string(bytes[start ..< index])
    }

    /// Reads `[[name, name(arguments), ...]]`, returning the attribute names and the argument of `host_name`.
    private mutating func readAttribute() -> ([String], String?) {
        index += 2
        var names: [String] = []
        var hostName: String?
        var depth = 0
        var expectsName = true
        var lastName: String?

        while index < bytes.count {
            let byte = bytes[index]

            if depth == 0, byte == UInt8(ascii: "]"), peek(1) == UInt8(ascii: "]") {
                index += 2
                break
            }

            switch byte {
            case UInt8(ascii: "\n"):
                newLine()
                continue
            case UInt8(ascii: "/") where peek(1) == UInt8(ascii: "/"):
                skipLineComment()
                continue
            case UInt8(ascii: "/") where peek(1) == UInt8(ascii: "*"):
                skipBlockComment()
                continue
            case UInt8(ascii: "\""), UInt8(ascii: "'"):
                let value = readQuoted()
                if depth == 1, lastName == "host_name" {
                    hostName = value
                }
                continue
            case UInt8(ascii: "("):
                depth += 1
            case UInt8(ascii: ")"):
                depth = max(0, depth - 1)
            case UInt8(ascii: ","):
                if depth == 0 {
                    expectsName = true
                }
            default:
                if Self.isIdentifierStart(byte) {
                    let identifier = readIdentifier()
                    if depth == 0, expectsName {
                        names.append(identifier)
                        lastName = identifier
                        expectsName = false
                    }
                    continue
                }
            }

            index += 1
        }

        return (names, hostName)
    }

    /// Reads a preprocessor directive up to the end of its last line, following line continuations.
    private mutating func readDirective() {
        index += 1
        var text: [UInt8] = []

        while index < bytes.count {
            let byte = bytes[index]

            if byte == UInt8(ascii: "\\"), peek(1) == UInt8(ascii: "\n") {
                index += 1
                newLine()
                text.append(UInt8(ascii: " "))
                continue
            }
            if byte == UInt8(ascii: "\\"), peek(1) == UInt8(ascii: "\r"), peek(2) == UInt8(ascii: "\n") {
                index += 2
                newLine()
                text.append(UInt8(ascii: " "))
                continue
            }
            if byte == UInt8(ascii: "\n") {
                break
            }
            if byte == UInt8(ascii: "/"), peek(1) == UInt8(ascii: "/") {
                skipLineComment()
                break
            }
            if byte == UInt8(ascii: "/"), peek(1) == UInt8(ascii: "*") {
                skipBlockComment()
                text.append(UInt8(ascii: " "))
                continue
            }

            text.append(byte)
            index += 1
        }

        let words = Self.identifiers(in: text)
        guard let directive = words.first else { return }

        switch directive {
        case "if", "ifdef", "ifndef":
            conditionalDepth += 1
        case "endif":
            conditionalDepth = max(0, conditionalDepth - 1)
        case "define":
            if words.dropFirst().contains(where: { Self.qualifierKeywords.contains($0) || $0 == "visible" || $0 == "stitchable" }) {
                definesFunctionsInMacros = true
            }
        default:
            break
        }
    }

    private static func identifiers(in text: [UInt8]) -> [String] {
        var identifiers: [String] = []
        var current: [UInt8] = []

        for byte in text + [UInt8(ascii: " ")] {
            if isIdentifierPart(byte), !(current.isEmpty && isDigit(byte)) {
                current.append(byte)
            } else if !current.isEmpty {
                identifiers.append(string(current[...]))
                current = []
            }
        }

        return identifiers
    }

    /// The bytes are delimited by ASCII characters of a source read as UTF-8, so they always decode.
    private static func string(_ bytes: ArraySlice<UInt8>) -> String {
        String(bytes: bytes, encoding: .utf8) ?? ""
    }

    private static func isIdentifierStart(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || byte == UInt8(ascii: "_")
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    private static func isIdentifierPart(_ byte: UInt8) -> Bool {
        isIdentifierStart(byte) || isDigit(byte)
    }
}
