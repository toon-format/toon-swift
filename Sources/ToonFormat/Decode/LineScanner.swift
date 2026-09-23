import Foundation

/// The lines of a document after the lexical pre-pass.
///
/// The pre-pass runs before every other step of decoding, as TOON
/// specification § 5.1 and § 12 require.
struct ScannedDocument {
    /// The lines to parse.
    ///
    /// The byte-order mark, the carriage returns, the trailing spaces and the
    /// comment lines are removed. Blank lines stay, because § 12 makes a blank
    /// line inside the span of a header an error.
    let lines: [String]

    /// The 1-based number of each line in the original document.
    ///
    /// The pre-pass drops the comment lines, so an index into ``lines`` is not
    /// the number that the reader of the document sees. An error message uses
    /// this table to report the original number.
    let sourceLineNumbers: [Int]
}

/// Runs the lexical pre-pass of TOON specification § 5.1 and § 12.
enum LineScanner {
    /// Splits the text into lines and removes what is not content.
    ///
    /// The steps run in the order that § 12 prescribes:
    ///
    /// 1. Remove a single U+FEFF at the very start of the document. A U+FEFF
    ///    anywhere else is content.
    /// 2. Exclude a carriage return at the end of a line, which accepts CRLF
    ///    input. A carriage return anywhere else in a line is content.
    /// 3. Strip the trailing spaces (U+0020) of a line. A line whose content
    ///    is `-` followed only by spaces is therefore the bare marker of an
    ///    empty-object list item. It is not a list item with an empty token.
    /// 4. Remove the comment lines (§ 5.1). A comment line is a line whose
    ///    first character after zero or more leading spaces is `#`. Only
    ///    spaces may precede the `#`, so a line indented with a tab is
    ///    content. Removal never creates or terminates a scope. A comment
    ///    between two tabular rows does not end them. A comment never counts
    ///    as a row, an entry, a list item or a blank line.
    /// - Parameters:
    ///   - indentSize: The number of spaces of one level, for the strict
    ///     indentation checks of section 12.
    ///   - strict: Whether to apply those checks. In non-strict mode the depth
    ///     uses the floor of the division, which section 12 permits.
    static func scan(_ text: String, indentSize: Int, strict: Bool) throws -> ScannedDocument {
        // The scan runs over Unicode scalars, not over Characters. Swift treats
        // "\r\n" as one grapheme cluster, so a split of a String on "\n" does
        // not divide a CRLF pair.
        let scalars = Array(text.unicodeScalars)
        let start = scalars.first == "\u{FEFF}" ? 1 : 0

        var lines: [String] = []
        var sourceLineNumbers: [Int] = []
        var lineStart = start
        var lineNumber = 1
        var index = start

        while index <= scalars.count {
            guard index == scalars.count || scalars[index] == "\n" else {
                index += 1
                continue
            }

            var end = index
            if end > lineStart, scalars[end - 1] == "\r" {
                end -= 1
            }
            while end > lineStart, scalars[end - 1] == " " {
                end -= 1
            }

            let content = scalars[lineStart ..< end]
            if !isCommentLine(content) {
                // Section 5.1 exempts a comment line from these checks, and a
                // blank line carries no indentation to check.
                if strict, !content.isEmpty {
                    try validateIndentation(
                        of: content,
                        indentSize: indentSize,
                        lineNumber: lineNumber
                    )
                }
                lines.append(String(String.UnicodeScalarView(content)))
                sourceLineNumbers.append(lineNumber)
            }

            lineNumber += 1
            lineStart = index + 1
            index += 1
        }

        return ScannedDocument(lines: lines, sourceLineNumbers: sourceLineNumbers)
    }

    /// Applies the strict indentation rules of specification 12.
    ///
    /// A tab in the indentation is an error. The number of leading spaces must
    /// be a multiple of the indent size.
    private static func validateIndentation(
        of line: ArraySlice<Unicode.Scalar>,
        indentSize: Int,
        lineNumber: Int
    ) throws {
        var spaces = 0
        var index = line.startIndex

        while index < line.endIndex {
            let scalar = line[index]
            if scalar == " " {
                spaces += 1
            } else if scalar == "\t" {
                throw TOONDecodingError.invalidIndentation(
                    line: lineNumber,
                    message: "A tab is not allowed in the indentation"
                )
            } else {
                break
            }
            index += 1
        }

        if indentSize > 0, spaces % indentSize != 0 {
            throw TOONDecodingError.invalidIndentation(
                line: lineNumber,
                message: "The indentation of \(spaces) spaces is not a multiple of \(indentSize)"
            )
        }
    }

    private static func isCommentLine(_ line: ArraySlice<Unicode.Scalar>) -> Bool {
        var index = line.startIndex
        while index < line.endIndex, line[index] == " " {
            index += 1
        }
        return index < line.endIndex && line[index] == "#"
    }
}
