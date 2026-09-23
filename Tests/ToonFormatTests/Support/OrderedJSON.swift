import Foundation

@testable import ToonFormat

/// A JSON reader that keeps the order of the keys of an object.
///
/// `JSONSerialization` returns an `NSDictionary`, and the order of
/// `KeyedDecodingContainer.allKeys` is undefined for `JSONDecoder`. Neither one
/// can report the order of the keys. The conformance fixtures need that order:
/// on encode, the order of the keys of the input sets the order of the output
/// lines (TOON specification § 2).
///
/// The reader unescapes strings on its own, and does not call into
/// ``ToonFormat``. A shared escape routine would let a fault in the library and
/// a fault in the test agree. The test would then pass.
enum OrderedJSON {
    struct ParseError: Error, CustomStringConvertible {
        let message: String
        let offset: Int

        var description: String { "\(message) at scalar offset \(offset)" }
    }

    static func parse(_ data: Data) throws -> TOONValue {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ParseError(message: "The input is not valid UTF-8", offset: 0)
        }
        return try parse(text)
    }

    static func parse(_ text: String) throws -> TOONValue {
        var parser = Parser(scalars: Array(text.unicodeScalars))
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.isAtEnd else {
            throw ParseError(message: "Unexpected trailing content", offset: parser.offset)
        }
        return value
    }

    private struct Parser {
        /// The deepest nesting that the reader follows.
        ///
        /// The reader calls itself for a nested value, so a file of many open
        /// brackets would overflow the stack and stop the test process. The
        /// limit turns that into an error. The fixtures nest about five deep.
        static let maximumDepth = 256

        let scalars: [Unicode.Scalar]
        var offset = 0
        var depth = 0

        var isAtEnd: Bool { offset >= scalars.count }

        private var current: Unicode.Scalar? {
            offset < scalars.count ? scalars[offset] : nil
        }

        mutating func skipWhitespace() {
            while let scalar = current,
                scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
            {
                offset += 1
            }
        }

        mutating func parseValue() throws -> TOONValue {
            skipWhitespace()
            guard let scalar = current else {
                throw ParseError(message: "Unexpected end of input", offset: offset)
            }
            switch scalar {
            case "{", "[":
                guard depth < Self.maximumDepth else {
                    throw ParseError(message: "The nesting is too deep", offset: offset)
                }
                depth += 1
                defer { depth -= 1 }
                return scalar == "{" ? try parseObject() : try parseArray()
            case "\"": return .string(try parseString())
            case "t":
                try expect("true")
                return .bool(true)
            case "f":
                try expect("false")
                return .bool(false)
            case "n":
                try expect("null")
                return .null
            default:
                return try parseNumber()
            }
        }

        private mutating func expect(_ literal: String) throws {
            for expected in literal.unicodeScalars {
                guard current == expected else {
                    throw ParseError(message: "Expected '\(literal)'", offset: offset)
                }
                offset += 1
            }
        }

        private mutating func parseObject() throws -> TOONValue {
            offset += 1  // '{'
            var object = TOONObject()
            skipWhitespace()
            if current == "}" {
                offset += 1
                return .object(object)
            }
            while true {
                skipWhitespace()
                guard current == "\"" else {
                    throw ParseError(message: "Expected a key", offset: offset)
                }
                let key = try parseString()
                skipWhitespace()
                guard current == ":" else {
                    throw ParseError(message: "Expected ':'", offset: offset)
                }
                offset += 1
                object[key] = try parseValue()
                skipWhitespace()
                switch current {
                case ",":
                    offset += 1
                case "}":
                    offset += 1
                    return .object(object)
                default:
                    throw ParseError(message: "Expected ',' or '}'", offset: offset)
                }
            }
        }

        private mutating func parseArray() throws -> TOONValue {
            offset += 1  // '['
            var items: [TOONValue] = []
            skipWhitespace()
            if current == "]" {
                offset += 1
                return .array(items)
            }
            while true {
                items.append(try parseValue())
                skipWhitespace()
                switch current {
                case ",":
                    offset += 1
                case "]":
                    offset += 1
                    return .array(items)
                default:
                    throw ParseError(message: "Expected ',' or ']'", offset: offset)
                }
            }
        }

        private mutating func parseString() throws -> String {
            offset += 1  // opening quote
            var result = String.UnicodeScalarView()
            while true {
                guard let scalar = current else {
                    throw ParseError(message: "Unterminated string", offset: offset)
                }
                offset += 1
                switch scalar {
                case "\"":
                    return String(result)
                case "\\":
                    result.append(try parseEscape())
                default:
                    // JSON needs an escape for a scalar below U+0020. A raw
                    // control scalar, a raw line feed among them, marks a
                    // damaged file, so the reader stops rather than take it.
                    guard scalar.value >= 0x20 else {
                        throw ParseError(
                            message: "A control scalar needs an escape",
                            offset: offset - 1
                        )
                    }
                    result.append(scalar)
                }
            }
        }

        private mutating func parseEscape() throws -> Unicode.Scalar {
            guard let marker = current else {
                throw ParseError(message: "Unterminated escape", offset: offset)
            }
            offset += 1
            switch marker {
            case "\"": return "\""
            case "\\": return "\\"
            case "/": return "/"
            case "b": return Unicode.Scalar(0x08)!
            case "f": return Unicode.Scalar(0x0C)!
            case "n": return "\n"
            case "r": return "\r"
            case "t": return "\t"
            case "u": return try parseUnicodeEscape()
            default:
                throw ParseError(message: "Unknown escape '\\\(marker)'", offset: offset)
            }
        }

        /// Reads `\uXXXX`, and joins a surrogate pair. JSON allows a surrogate
        /// pair here, and the TOON format does not. That is why this routine
        /// stays separate from the escape code of the library.
        private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
            let first = try parseHexQuad()
            if first >= 0xD800, first <= 0xDBFF {
                guard current == "\\", offset + 1 < scalars.count, scalars[offset + 1] == "u" else {
                    throw ParseError(message: "Expected a low surrogate", offset: offset)
                }
                offset += 2
                let second = try parseHexQuad()
                guard second >= 0xDC00, second <= 0xDFFF else {
                    throw ParseError(message: "Invalid low surrogate", offset: offset)
                }
                let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                guard let scalar = Unicode.Scalar(combined) else {
                    throw ParseError(message: "Invalid surrogate pair", offset: offset)
                }
                return scalar
            }
            guard let scalar = Unicode.Scalar(first) else {
                throw ParseError(message: "Invalid code point", offset: offset)
            }
            return scalar
        }

        private mutating func parseHexQuad() throws -> UInt32 {
            var value: UInt32 = 0
            for _ in 0 ..< 4 {
                guard let scalar = current, let digit = scalar.hexDigitValue else {
                    throw ParseError(message: "Expected a hexadecimal digit", offset: offset)
                }
                value = value << 4 | UInt32(digit)
                offset += 1
            }
            return value
        }

        /// Reads a number, and follows the grammar of JSON exactly.
        ///
        /// An earlier reader took every digit, sign, dot and exponent letter,
        /// then handed the token to `Int64(_:)` or `Double(_:)`. Both have a
        /// wider grammar than JSON, so the reader accepted `007`, `+5`, `.5`
        /// and `1.`. The oracle of a conformance suite must not be looser
        /// than the format it reads.
        private mutating func parseNumber() throws -> TOONValue {
            let start = offset
            var isDouble = false

            if current == "-" { offset += 1 }

            // The integer part is a single zero, or a digit from 1 to 9 and
            // then any digits.
            guard let first = current, first.isASCIIDigit else {
                throw ParseError(message: "Expected a digit", offset: offset)
            }
            offset += 1
            if first != "0" {
                while let scalar = current, scalar.isASCIIDigit { offset += 1 }
            }

            if current == "." {
                offset += 1
                guard let scalar = current, scalar.isASCIIDigit else {
                    throw ParseError(message: "Expected a digit after the point", offset: offset)
                }
                while let scalar = current, scalar.isASCIIDigit { offset += 1 }
                isDouble = true
            }

            if current == "e" || current == "E" {
                offset += 1
                if current == "+" || current == "-" { offset += 1 }
                guard let scalar = current, scalar.isASCIIDigit else {
                    throw ParseError(
                        message: "Expected a digit in the exponent",
                        offset: offset
                    )
                }
                while let scalar = current, scalar.isASCIIDigit { offset += 1 }
                isDouble = true
            }

            let token = String(String.UnicodeScalarView(scalars[start ..< offset]))
            if !isDouble, let integer = Int64(token) {
                return .int(integer)
            }
            guard let number = Double(token), number.isFinite else {
                throw ParseError(message: "The number '\(token)' does not fit", offset: start)
            }
            return .double(number)
        }
    }
}

extension Unicode.Scalar {
    fileprivate var isASCIIDigit: Bool { self >= "0" && self <= "9" }

    fileprivate var hexDigitValue: Int? {
        switch self {
        case "0" ... "9": return Int(value - 0x30)
        case "a" ... "f": return Int(value - 0x61) + 10
        case "A" ... "F": return Int(value - 0x41) + 10
        default: return nil
        }
    }
}
