import Foundation

/// The number grammar of TOON specification § 4.
///
/// An unquoted token decodes as a number if and only if it matches
/// `^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$` with ASCII digits only, and
/// carries no forbidden leading zero. Every other token decodes as a string,
/// among them `.5`, `1.`, `+5`, `Infinity`, `NaN`, `0x10` and `1_000`.
///
/// The specification states that a decoder MUST NOT delegate this decision to
/// a parser of the host language with a wider grammar. Swift is a bad case:
/// `Int64("+5")` succeeds, and `Double(_:)` follows `strtod`, which accepts
/// `0x10`, `Infinity`, `nan`, `.5` and `1.`. This type therefore matches the
/// grammar over the scalars first, and converts only after a match.
enum NumberGrammar {
    /// The shape of a token that matches the grammar.
    enum Form {
        /// The token has no fractional part and no exponent.
        case integer
        /// The token has a fractional part, an exponent, or both.
        case decimal
    }

    /// Returns the shape of the token, or `nil` when the token is not a number.
    static func form(of token: String) -> Form? {
        let scalars = Array(token.unicodeScalars)
        var index = 0

        if index < scalars.count, scalars[index] == "-" {
            index += 1
        }

        // Integer part: at least one digit.
        let integerStart = index
        while index < scalars.count, scalars[index].isASCIIDigit {
            index += 1
        }
        let integerDigits = index - integerStart
        guard integerDigits > 0 else { return nil }

        // A leading zero is forbidden unless the integer part is a single
        // zero. `0.5`, `0e1`, `-0.5` and `-0e1` stay numbers; `05`, `0001`,
        // `-05` and `-0001` are strings.
        if integerDigits > 1, scalars[integerStart] == "0" {
            return nil
        }

        var form = Form.integer

        if index < scalars.count, scalars[index] == "." {
            index += 1
            let fractionStart = index
            while index < scalars.count, scalars[index].isASCIIDigit {
                index += 1
            }
            guard index > fractionStart else { return nil }
            form = .decimal
        }

        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            index += 1
            if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
                index += 1
            }
            let exponentStart = index
            while index < scalars.count, scalars[index].isASCIIDigit {
                index += 1
            }
            guard index > exponentStart else { return nil }
            form = .decimal
        }

        guard index == scalars.count else { return nil }
        return form
    }

    /// Converts a token that matches the grammar into a value.
    ///
    /// A number that the host type cannot hold stays a string. The library
    /// documents that policy, which § 4 allows, and it is what lets
    /// `UInt64` values above `Int64.max` survive a round trip.
    ///
    /// The rule covers both shapes. An integer that does not fit `Int64` stays
    /// a string. A decimal whose exponent overflows `Double` stays a string
    /// too. `Double(_:)` reports an overflow as an infinity, not as `nil`, and
    /// an infinity has no place in the data model of § 2.
    static func value(of token: String) -> Value? {
        switch form(of: token) {
        case .integer:
            if let integer = Int64(token) {
                return .int(integer)
            }
            return .string(token)
        case .decimal:
            guard let number = Double(token), number.isFinite else {
                return .string(token)
            }
            return .double(number)
        case nil:
            return nil
        }
    }
}

extension Unicode.Scalar {
    /// `true` for U+0030 to U+0039 only.
    ///
    /// The `\d` class of `NSRegularExpression` matches every Unicode decimal
    /// digit, which § 4 forbids.
    var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}
