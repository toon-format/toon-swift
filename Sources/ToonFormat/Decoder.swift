import Foundation

/// A decoder that converts TOON format data into Swift values.
///
/// This decoder conforms to the TOON (Token-Oriented Object Notation) specification version 4.1.
/// For more information, see https://github.com/toon-format/spec
public final class TOONDecoder {
    /// The path expansion mode for dotted keys.
    ///
    /// Use this property to control how the decoder interprets dotted keys
    /// like `a.b.c: value`. When you enable path expansion, the decoder
    /// converts dotted keys into nested objects. This is the inverse of
    /// ``TOONEncoder/keyFolding``.
    ///
    /// For example, with ``PathExpansion/safe`` or ``PathExpansion/automatic``,
    /// the following TOON input:
    ///
    /// ```toon
    /// user.profile.name: John
    /// ```
    ///
    /// Becomes equivalent to:
    ///
    /// ```toon
    /// user:
    ///   profile:
    ///     name: John
    /// ```
    @available(
        *,
        deprecated,
        message: """
            TOON specification 4.0 removed path expansion. A dotted key is one \
            literal key. The option still works, and its default is now \
            .disabled so that the decoder follows specification 4.1. It is \
            removed in 2.0.
            """
    )
    public var expandPaths: PathExpansion {
        get { storedExpandPaths }
        set { storedExpandPaths = newValue }
    }

    /// Backing storage, so that the library can read the option without
    /// raising its own deprecation warning.
    private var storedExpandPaths: PathExpansion = .disabled

    /// The number of spaces of one indentation level.
    ///
    /// TOON specification 13 defines this option, with a default of 2.
    /// Section 13.2 is the conformance checklist of a decoder, and defines no
    /// option.
    ///
    /// Earlier releases read the indentation size from the first indented line
    /// of the document. That guess is not part of the specification, and it
    /// misreads a document whose first nested value is deeper than one level.
    /// Set this property to decode a document that uses a different size:
    ///
    /// ```swift
    /// let decoder = TOONDecoder()
    /// decoder.indentSize = 4
    /// ```
    public var indentSize: Int = 2

    /// Whether to enforce the strict-mode rules of TOON specification 14.
    ///
    /// TOON specification 13 defines this option, with a default of `true`.
    ///
    /// In strict mode a document must satisfy every rule of section 14. The
    /// declared counts must match. A field name must not repeat. The
    /// indentation must be exact. In non-strict mode a decoder resolves what it
    /// can, for example a repeated key by last write wins (section 14.3).
    ///
    /// Set this property to `false` to accept a document that an earlier
    /// release accepted but section 14 rejects.
    public var strict: Bool = true

    /// Limits for decoding to prevent resource exhaustion.
    ///
    /// Use this to protect against malicious or malformed input when parsing untrusted data.
    public var limits: DecodingLimits = .default

    /// Path expansion mode.
    ///
    /// Path expansion determines how dotted keys (e.g., `user.profile.name`) are interpreted
    /// during decoding. This enables a more compact representation of nested data structures.
    public enum PathExpansion: Hashable, Sendable {
        /// Automatic path expansion.
        ///
        /// Expands dotted keys when they match the target type's structure,
        /// falling back gracefully to literal string keys if expansion causes conflicts.
        ///
        /// This mode is ideal when you want the convenience of path expansion
        /// without risking decoding failures. If a dotted key like `a.b` would conflict
        /// with an existing key `a` that isn't an object, the decoder treats `a.b`
        /// as a literal key instead of throwing an error.
        ///
        /// Use this mode when decoding data that may contain a mix of dotted paths
        /// and literal keys with dots.
        case automatic

        /// No path expansion.
        ///
        /// Dotted keys are decoded as literal strings without any transformation.
        /// A key like `user.profile.name` remains a single key with that exact name,
        /// rather than being expanded into a nested `user` -> `profile` -> `name` structure.
        ///
        /// Use this mode when your data model uses dots in key names literally,
        /// or when you need complete control over key interpretation.
        case disabled

        /// Safe path expansion with collision detection.
        ///
        /// Expands dotted keys into nested objects, throwing ``TOONDecodingError/pathCollision(path:line:)``
        /// if expansion would conflict with existing keys.
        ///
        /// A collision occurs when a dotted path like `a.b.c` requires `a.b` to be an object,
        /// but `a.b` already exists as a non-object value (or vice versa).
        ///
        /// Use this mode when you want strict validation and prefer explicit errors
        /// over silent fallback behavior.
        case safe
    }

    /// Limits for decoding to prevent resource exhaustion.
    public struct DecodingLimits: Hashable, Sendable {
        /// Maximum input size in bytes.
        public var maxInputSize: Int

        /// Maximum nesting depth.
        public var maxDepth: Int

        /// Maximum number of keys in a single object.
        public var maxObjectKeys: Int

        /// Maximum array length.
        public var maxArrayLength: Int

        /// Default limits suitable for most use cases.
        ///
        /// - `maxInputSize`: 10 MB
        /// - `maxDepth`: 32 (prevents stack overflow from deep nesting)
        /// - `maxObjectKeys`: 10,000
        /// - `maxArrayLength`: 100,000
        public static let `default` = DecodingLimits(
            maxInputSize: 10 * 1024 * 1024,
            maxDepth: 32,
            maxObjectKeys: 10_000,
            maxArrayLength: 100_000
        )

        /// Decoding limits that impose no restrictions.
        ///
        /// - Warning: This configuration is unsafe for untrusted input
        ///   and should only be used with data from trusted sources.
        ///   Without limits, malicious input can cause excessive memory usage,
        ///   stack overflow from deep nesting, or denial-of-service attacks.
        ///
        /// Use this only when you have full control over the input data
        /// and need to decode arbitrarily large or complex TOON structures.
        ///
        /// For production use with external input, use ``default`` or
        /// ``init(maxInputSize:maxDepth:maxObjectKeys:maxArrayLength:)``
        /// with appropriate limits instead.
        public static let unlimited = DecodingLimits(
            maxInputSize: .max,
            maxDepth: .max,
            maxObjectKeys: .max,
            maxArrayLength: .max
        )

        public init(maxInputSize: Int, maxDepth: Int, maxObjectKeys: Int, maxArrayLength: Int) {
            self.maxInputSize = maxInputSize
            self.maxDepth = maxDepth
            self.maxObjectKeys = maxObjectKeys
            self.maxArrayLength = maxArrayLength
        }
    }

    /// Creates a new TOON decoder with default configuration.
    ///
    /// Default settings:
    /// - `indentSize`: 2
    /// - `strict`: `true`
    /// - `expandPaths`: `.disabled`
    /// - `limits`: `.default`
    public init() {}

    /// Decodes TOON format data into the specified type.
    ///
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - data: UTF-8 encoded TOON data.
    /// - Returns: The decoded value.
    /// - Throws: ``TOONDecodingError`` if decoding fails.
    public func decode<T: Decodable>(_: T.Type, from data: Data) throws -> T {
        // A size below one makes every line land at depth zero, so the
        // decoder would flatten the document rather than report the mistake.
        guard indentSize >= 1 else {
            throw TOONDecodingError.invalidFormat(
                "The indentation size must be one or more, not \(indentSize)"
            )
        }

        if data.count > limits.maxInputSize {
            throw TOONDecodingError.inputTooLarge(size: data.count, limit: limits.maxInputSize)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw TOONDecodingError.invalidFormat("Data is not valid UTF-8")
        }

        let parser = try Parser(
            text: text,
            indentSize: indentSize,
            strict: strict,
            expandPaths: storedExpandPaths,
            limits: limits
        )
        let value = try parser.parse()

        let decoder = Decoder(value: value, codingPath: [], userInfo: [:])
        return try T(from: decoder)
    }

    /// Decodes a TOON document into the given type.
    ///
    /// TOON specification 4 scopes its rule about ill-formed UTF-8 to byte
    /// input, so this overload, which takes text that is already decoded,
    /// does not apply it.
    ///
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - text: The document text.
    /// - Returns: The decoded value.
    /// - Throws: ``TOONDecodingError`` if decoding fails.
    public func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        try decode(type, from: Data(text.utf8))
    }
}

// MARK: - Decoding Errors

/// Errors that can occur during TOON decoding.
public enum TOONDecodingError: Error, Equatable {
    /// The input data is not valid UTF-8 or has an invalid structure.
    case invalidFormat(String)

    /// Invalid indentation at the specified line.
    case invalidIndentation(line: Int, message: String)

    /// Invalid escape sequence in a string.
    case invalidEscapeSequence(String)

    /// Array element count doesn't match the declared length.
    case countMismatch(expected: Int, actual: Int, line: Int)

    /// Row field count doesn't match the header field count.
    case fieldCountMismatch(expected: Int, actual: Int, line: Int)

    /// Unexpected blank line inside an array or tabular block.
    case unexpectedBlankLine(line: Int)

    /// Invalid array header format.
    case invalidHeader(String)

    /// Type mismatch during decoding.
    case typeMismatch(expected: String, actual: String)

    /// Required key not found in the object.
    case keyNotFound(String)

    /// Data is corrupted or invalid.
    case dataCorrupted(String)

    /// Path expansion collision detected.
    case pathCollision(path: String, line: Int)

    /// Input size exceeds the limit.
    case inputTooLarge(size: Int, limit: Int)

    /// Nesting depth exceeds the limit.
    case depthLimitExceeded(depth: Int, limit: Int)

    /// Object has too many keys.
    case objectKeyLimitExceeded(count: Int, limit: Int)

    /// Array length exceeds the limit.
    case arrayLengthLimitExceeded(length: Int, limit: Int)
}

// MARK: - Parser

private final class Parser {
    private let lines: [String]
    private let indentSize: Int
    private let strict: Bool
    private let sourceLineNumbers: [Int]
    private let expandPaths: TOONDecoder.PathExpansion
    private let limits: TOONDecoder.DecodingLimits
    private var currentLine: Int = 0

    init(
        text: String,
        indentSize: Int,
        strict: Bool,
        expandPaths: TOONDecoder.PathExpansion,
        limits: TOONDecoder.DecodingLimits
    ) throws {
        let document = try LineScanner.scan(text, indentSize: indentSize, strict: strict)
        lines = document.lines
        sourceLineNumbers = document.sourceLineNumbers
        self.indentSize = indentSize
        self.strict = strict
        self.expandPaths = expandPaths
        self.limits = limits
    }

    /// Maps an index into ``lines`` to the line number of the original
    /// document. The pre-pass drops the comment lines, so the two differ.
    private func sourceLine(_ index: Int) -> Int {
        if index >= 0, index < sourceLineNumbers.count {
            return sourceLineNumbers[index]
        }
        if index < 0 {
            return sourceLineNumbers.first ?? 1
        }
        return (sourceLineNumbers.last ?? 0) + 1
    }

    /// The line number of the line that ``consumeLine`` returned last.
    ///
    /// An error found after the read of a line must name that line, not the
    /// line that follows it. ``currentLine`` already points past the line at
    /// that moment.
    private var lastReadSourceLine: Int { sourceLine(currentLine - 1) }

    /// Rejects a line that follows a root scope.
    ///
    /// Specification 5 gives a document one root value. A line left over after
    /// the root array or the root keyed scope is trailing content.
    ///
    /// Specification 14.2 makes that an error in strict mode. A decoder
    /// outside strict mode may ignore the line instead, and the reference
    /// implementation does.
    private func rejectTrailingContentAfterRoot() throws {
        guard strict else { return }

        while currentLine < lines.count {
            if !lines[currentLine].isEmpty {
                throw TOONDecodingError.invalidFormat(
                    "Trailing content after the root value, at line \(sourceLine(currentLine))"
                )
            }
            currentLine += 1
        }
    }

    func parse() throws -> Value {
        // Filter out empty lines for root detection, but keep track of original positions
        let nonEmptyLines = lines.enumerated().filter { !$0.element.isEmpty }

        if nonEmptyLines.isEmpty {
            // Empty document = empty object
            return .object([:])
        }

        // Detect root form
        let firstNonEmptyLine = nonEmptyLines[0].element
        let firstContent = trimIndentation(firstNonEmptyLine).content

        // Specification 4 gives the literal token `[]` at the root the meaning
        // of an empty array.
        if firstContent == "[]", nonEmptyLines.count == 1 {
            return .array([])
        }

        // Root array: first line is a valid array header WITHOUT a key (e.g., "[3]:" not "items[3]:")
        // An array header without key starts with "[" immediately
        if firstContent.hasPrefix("["), let _ = try? parseArrayHeader(String(firstContent)) {
            currentLine = nonEmptyLines[0].offset
            let root = try parseArrayAtCurrentLine(depth: 0, key: nil)
            try rejectTrailingContentAfterRoot()
            return root
        }

        // Single primitive: exactly one non-empty line that's not an object key-value pair
        // A key-value pair has a colon NOT inside quotes and NOT part of an array header
        if nonEmptyLines.count == 1 {
            let contentStr = String(firstContent)
            if !isKeyValuePair(contentStr) {
                return try parsePrimitiveValue(contentStr)
            }
        }

        // Default: object
        currentLine = 0
        return try parseObject(atDepth: 0)
    }

    /// Checks if a line represents a key: value pair (as opposed to a single primitive value)
    private func isKeyValuePair(_ content: String) -> Bool {
        var inQuotes = false
        var escaped = false
        var bracketDepth = 0

        for char in content {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                continue
            }

            if !inQuotes {
                if char == "[" {
                    bracketDepth += 1
                } else if char == "]" {
                    bracketDepth -= 1
                } else if char == ":" && bracketDepth == 0 {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Indentation Handling

    /// Splits a line into its depth and its content.
    ///
    /// The depth uses the floor of the division. TOON specification 12 allows
    /// that leniency for an indentation that is not a multiple of the indent
    /// size. Strict mode rejects such a line in the pre-pass.
    ///
    /// Specification 12 also allows a decoder to accept a tab in the
    /// indentation outside strict mode. It requires the depth rule for a tab to
    /// be documented. This decoder counts one tab as one level. Strict mode
    /// rejects a tab in the pre-pass, so a tab reaches this point only in
    /// non-strict mode.
    private func trimIndentation(_ line: String) -> (depth: Int, content: Substring) {
        var spaces = 0
        var tabs = 0
        var index = line.startIndex

        while index < line.endIndex {
            if line[index] == " " {
                spaces += 1
            } else if line[index] == "\t" {
                tabs += 1
            } else {
                break
            }
            index = line.index(after: index)
        }

        let depth = (indentSize > 0 ? spaces / indentSize : 0) + tabs
        return (depth, line[index...])
    }

    private func peekLine() -> String? {
        guard currentLine < lines.count else { return nil }
        return lines[currentLine]
    }

    private func consumeLine() -> String? {
        guard currentLine < lines.count else { return nil }
        let line = lines[currentLine]
        currentLine += 1
        return line
    }

    /// Skips the blank lines, and rejects one that sits inside a scope.
    ///
    /// Specification 12 forbids a blank line inside the span of a header. The
    /// span runs from the first row, entry or item of the scope. It ends at the
    /// last line of the content of that scope. A blank line before the first
    /// one is therefore ignorable, and so is a blank line after the last one. A
    /// blank line is interior when the scope has already produced an element
    /// and the next line still belongs to the scope.
    private func skipBlankLines(insideScopeAtDepth depth: Int, hasElement: Bool) throws {
        guard currentLine < lines.count, lines[currentLine].isEmpty else { return }

        guard let nextDepth = depthOfNextContentLine() else {
            // Only blank lines remain, so nothing encloses them.
            while currentLine < lines.count, lines[currentLine].isEmpty {
                currentLine += 1
            }
            return
        }

        // The next line is shallower, so the blank lines sit after this scope
        // and belong to an enclosing one. Leave them for it to judge.
        if nextDepth < depth { return }

        let firstBlank = currentLine
        while currentLine < lines.count, lines[currentLine].isEmpty {
            currentLine += 1
        }

        if strict, hasElement {
            throw TOONDecodingError.unexpectedBlankLine(line: sourceLine(firstBlank))
        }
    }

    /// The depth of the next line that is not blank, without consuming
    /// anything. Returns `nil` at the end of the document.
    private func depthOfNextContentLine() -> Int? {
        var index = currentLine
        while index < lines.count, lines[index].isEmpty {
            index += 1
        }
        guard index < lines.count else { return nil }
        return trimIndentation(lines[index]).depth
    }

    private func skipEmptyLines() {
        while currentLine < lines.count, lines[currentLine].isEmpty {
            currentLine += 1
        }
    }

    /// Stores a sibling key, per TOON specification 14.3.
    ///
    /// A repeated key is an error in strict mode. Otherwise the last write
    /// wins, and the key keeps the position of its first appearance.
    ///
    /// Two keys are the same key only when their Unicode scalar sequences are
    /// equal, per section 2 and section 16. ``ObjectStorage`` gives that
    /// identity, so two keys that differ only in normalization form stay
    /// apart.
    private func storeKey(
        _ key: String,
        value: Value,
        into values: inout ObjectStorage
    ) throws {
        if values[key] != nil, strict {
            throw TOONDecodingError.invalidFormat(
                "Duplicate key '\(key)' at line \(lastReadSourceLine)"
            )
        }

        values[key] = value
    }

    // MARK: - Object Parsing

    private func parseObject(atDepth depth: Int) throws -> Value {
        // Check depth limit
        if depth > limits.maxDepth {
            throw TOONDecodingError.depthLimitExceeded(depth: depth, limit: limits.maxDepth)
        }

        var values: ObjectStorage = [:]

        while let line = peekLine() {
            // Skip empty lines between object entries
            if line.isEmpty {
                _ = consumeLine()
                continue
            }

            let (lineDepth, content) = trimIndentation(line)

            // If we've decreased in depth, we're done with this object
            if lineDepth < depth {
                break
            }

            // If depth doesn't match expected, error
            if lineDepth != depth {
                throw TOONDecodingError.invalidIndentation(
                    line: sourceLine(currentLine),
                    message: "Expected indentation depth \(depth), got \(lineDepth)"
                )
            }

            _ = consumeLine()

            // Parse the key-value pair
            let (key, value) = try parseKeyValuePair(String(content), atDepth: depth)

            // Handle path expansion if enabled
            if (expandPaths == .safe || expandPaths == .automatic) && key.contains(".") && key.isValidDottedPath {
                do {
                    try expandDottedKey(key, value: value, into: &values)
                } catch {
                    // For .automatic mode, fall back to literal key on collision
                    if expandPaths == .automatic {
                        values[key] = value
                    } else {
                        throw error
                    }
                }
            } else {
                try storeKey(key, value: value, into: &values)
            }

            // Check object key limit
            if values.count > limits.maxObjectKeys {
                throw TOONDecodingError.objectKeyLimitExceeded(count: values.count, limit: limits.maxObjectKeys)
            }
        }

        return .object(values)
    }

    private func parseKeyValuePair(_ content: String, atDepth depth: Int) throws -> (String, Value) {
        // Specification 5.2 classifies the line before anything reads it. A
        // line whose first unquoted colon precedes any unquoted bracket is a
        // key-value line, never a header.
        if isArrayHeaderLine(content) {
            var parsedHeader: ArrayHeader?
            do {
                parsedHeader = try parseArrayHeader(content)
            } catch {
                // A malformed header is an error in strict mode. Non-strict
                // mode may fall through to the key-value reading below.
                if strict { throw error }
            }

            if let header = parsedHeader, header.fields != nil,
                hasContentAfterHeaderColon(content)
            {
                // Specification 6 forbids content after the colon of a header
                // that carries a field list: its rows live on the lines below.
                if strict {
                    throw TOONDecodingError.invalidHeader(
                        "Content after the colon of a header that carries a field list: \(content)"
                    )
                }
                parsedHeader = nil
            }

            if let header = parsedHeader {
                // Specification 6 allows a keyless header only at the document
                // root and, without a field list, as a list item.
                if header.key == nil, strict {
                    throw TOONDecodingError.invalidHeader(
                        "A keyless array header is not allowed in object field position: \(content)"
                    )
                }
                let array = try parseArrayContent(header: header, atDepth: depth)
                return (header.key ?? "", array)
            }
        }

        // Check for list item starting with "- "
        if content.hasPrefix("- ") {
            throw TOONDecodingError.invalidFormat(
                "Unexpected list item outside array context at line \(lastReadSourceLine)"
            )
        }

        // Parse as key: value
        guard let colonIndex = findKeyValueSeparator(in: content) else {
            throw TOONDecodingError.invalidFormat("Expected key: value at line \(lastReadSourceLine), got: \(content)")
        }

        let keyPart = String(content[..<colonIndex])
        let key = try parseKey(keyPart)

        let afterColon = content.index(after: colonIndex)
        let valuePart = String(content[afterColon...]).trimmingLeadingSpace()

        if valuePart.isEmpty {
            // Nested object or empty value
            let nestedValue = try parseNestedValue(atDepth: depth + 1)
            return (key, nestedValue)
        } else {
            // Inline value
            let value = try parseValueInValuePosition(valuePart)
            return (key, value)
        }
    }

    private func findKeyValueSeparator(in content: String) -> String.Index? {
        // Find the colon that separates key from value
        // Handle quoted keys: "key:with:colons": value
        var inQuotes = false
        var escaped = false
        var bracketDepth = 0

        for (i, char) in content.enumerated() {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                continue
            }

            if !inQuotes {
                if char == "[" {
                    bracketDepth += 1
                } else if char == "]" {
                    bracketDepth -= 1
                } else if char == ":", bracketDepth == 0 {
                    return content.index(content.startIndex, offsetBy: i)
                }
            }
        }

        return nil
    }

    private func parseKey(_ keyPart: String) throws -> String {
        let trimmed = keyPart.trimmingSpaces()

        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            // Quoted key
            let inner = String(trimmed.dropFirst().dropLast())
            return try unescapeString(inner)
        }

        // Unquoted key
        return trimmed
    }

    private func parseNestedValue(atDepth depth: Int) throws -> Value {
        skipEmptyLines()

        guard let line = peekLine() else {
            return .object([:])
        }

        let (lineDepth, content) = trimIndentation(line)

        if lineDepth < depth {
            // No nested content - empty object
            return .object([:])
        }

        if lineDepth != depth {
            throw TOONDecodingError.invalidIndentation(
                line: sourceLine(currentLine),
                message: "Expected indentation depth \(depth), got \(lineDepth)"
            )
        }

        // Check if it's a list item
        if content.hasPrefix("- ") {
            // This shouldn't happen here - arrays should be parsed via array header
            throw TOONDecodingError.invalidFormat("Unexpected list item at line \(sourceLine(currentLine))")
        }

        // Parse as nested object
        return try parseObject(atDepth: depth)
    }

    // MARK: - Array Parsing

    private struct ArrayHeader {
        let key: String?
        let count: Int
        let delimiter: String
        let fields: [FieldNode]?
        /// The `[N:]` marker of specification 9.5.
        let isKeyed: Bool
    }

    /// The position of the colon that ends an array header.
    ///
    /// The search skips a quoted span, the bracket segment and the field list.
    /// Each of the three may hold a colon of its own. The keyed marker of
    /// specification 9.5 sits inside the brackets, and a quoted field name may
    /// carry any character.
    private func headerColonIndex(in text: Substring) -> Substring.Index? {
        var inQuotes = false
        var escaped = false
        var brackets = 0
        var braces = 0
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inQuotes.toggle()
            } else if !inQuotes {
                switch char {
                case "[": brackets += 1
                case "]": brackets -= 1
                case "{": braces += 1
                case "}": braces -= 1
                case ":" where brackets == 0 && braces == 0:
                    return index
                default: break
                }
            }
            index = text.index(after: index)
        }

        return nil
    }

    /// Whether the header line carries content after the colon that ends it.
    private func hasContentAfterHeaderColon(_ content: String) -> Bool {
        guard let colonIndex = headerColonIndex(in: content[...]) else { return false }
        return !content[content.index(after: colonIndex)...].trimmingLeadingSpace().isEmpty
    }

    /// Whether the line is an array-header line, per specification 5.2.
    ///
    /// The line is a header when an unquoted bracket precedes the first
    /// unquoted colon. A bracket inside a quoted key, or after the colon, is
    /// content.
    private func isArrayHeaderLine(_ content: String) -> Bool {
        var inQuotes = false
        var escaped = false

        for char in content {
            if escaped {
                escaped = false
                continue
            }
            if char == "\\" {
                escaped = true
                continue
            }
            if char == "\"" {
                inQuotes.toggle()
                continue
            }
            guard !inQuotes else { continue }
            if char == "[" { return true }
            if char == ":" { return false }
        }

        return false
    }

    /// Parses an array header, or returns `nil` when the line is not one.
    ///
    /// Specification 5.2 classifies a line as an array header when an
    /// unquoted `[` comes before the first unquoted colon. A line of that
    /// shape that does not parse is a defect, not a key-value pair.
    /// Specification 6 lets a decoder outside strict mode fall back to a
    /// key-value pair, so only strict mode reports the defect.
    private func parseHeaderIfPresent(_ content: String) throws -> ArrayHeader? {
        // A header always ends with a colon. A line such as `[1,2,3]` carries
        // no colon, so specification 5.2 leaves it a scalar, not a defective
        // header.
        guard isArrayHeaderLine(content), headerColonIndex(in: content[...]) != nil else {
            return nil
        }
        do {
            return try parseArrayHeader(content)
        } catch {
            if strict { throw error }
            return nil
        }
    }

    private func parseArrayHeader(_ content: String) throws -> ArrayHeader {
        // Pattern: [key][N{delimiter}]{fields}:
        // Examples: [3]:, key[2]:, items[3]{a,b,c}:, items[2|]{a|b}:

        var remaining = content[...]

        // Extract key (optional)
        var key: String? = nil
        if remaining.first == "\"" {
            // Quoted key
            guard let endQuote = findClosingQuote(in: remaining) else {
                throw TOONDecodingError.invalidHeader("Unterminated quoted key in: \(content)")
            }
            let quotedKey = String(remaining[remaining.index(after: remaining.startIndex) ..< endQuote])
            key = try unescapeString(quotedKey)
            remaining = remaining[remaining.index(after: endQuote)...]
        } else if let bracketIndex = remaining.firstIndex(of: "[") {
            let keyPart = remaining[..<bracketIndex]
            if !keyPart.isEmpty {
                // Specification 6 forbids whitespace between a key and its
                // bracket segment; the token trimming of section 12 does not
                // reach here.
                if keyPart.last == " " || keyPart.last == "\t" {
                    throw TOONDecodingError.invalidHeader(
                        "Whitespace between the key and its bracket segment: \(content)"
                    )
                }
                key = String(keyPart)
            }
            remaining = remaining[bracketIndex...]
        }

        // Must have bracket
        guard remaining.first == "[" else {
            throw TOONDecodingError.invalidHeader("Expected '[' in array header: \(content)")
        }
        remaining = remaining.dropFirst()

        // Reject length marker # (removed in TOON v2.0)
        if remaining.first == "#" {
            throw TOONDecodingError.invalidHeader(
                "A length marker '#' is not part of the format: \(content)"
            )
        }

        // Parse count
        // ASCII digits only. Character.isNumber matches every Unicode digit,
        // which specification 6 does not allow here.
        var countStr = ""
        while let char = remaining.first, char.isASCIIDigit {
            countStr.append(char)
            remaining = remaining.dropFirst()
        }

        guard let count = Int(countStr) else {
            throw TOONDecodingError.invalidHeader("Invalid count in array header: \(content)")
        }

        // Specification 6 forbids a leading zero in the length.
        if countStr.count > 1, countStr.hasPrefix("0") {
            throw TOONDecodingError.invalidHeader(
                "Leading zero in the length of an array header: \(content)"
            )
        }

        // A colon immediately after the length marks a keyed header
        // (specification 9.5). The delimiter follows the colon, so `[2:|]` is
        // well-formed while `[2|:]` is not.
        var isKeyed = false
        if remaining.first == ":" {
            isKeyed = true
            remaining = remaining.dropFirst()
        }

        // Check for delimiter indicator
        var delimiter = ","
        if let first = remaining.first, first == "|" || first == "\t" {
            delimiter = String(first)
            remaining = remaining.dropFirst()
        }

        // Must have closing bracket
        guard remaining.first == "]" else {
            throw TOONDecodingError.invalidHeader("Expected ']' in array header: \(content)")
        }
        remaining = remaining.dropFirst()

        // Check for fields
        var fields: [FieldNode]? = nil
        if remaining.first == "{" {
            remaining = remaining.dropFirst()
            // The matching brace, not the first one: a nested field group of
            // specification 9.3 closes its own braces inside the list.
            guard let closeBrace = findMatchingBrace(in: remaining) else {
                throw TOONDecodingError.invalidHeader(
                    "Unterminated fields in array header: \(content)"
                )
            }
            let fieldsStr = String(remaining[..<closeBrace])
            let parsed = try parseFieldsList(fieldsStr, delimiter: delimiter)
            // Specification 14.2 makes a repeated name a strict-mode error.
            // Names repeated at different levels of nesting are not
            // duplicates, which firstDuplicateName() accounts for.
            if strict, let duplicate = parsed.firstDuplicateName() {
                throw TOONDecodingError.invalidHeader(
                    "Duplicate field name '\(duplicate)' in array header: \(content)"
                )
            }
            fields = parsed
            remaining = remaining[remaining.index(after: closeBrace)...]
        }

        // Must end with colon
        guard remaining.first == ":" else {
            throw TOONDecodingError.invalidHeader("Expected ':' at end of array header: \(content)")
        }

        // Specification 9.5 requires a field list on a keyed header.
        if isKeyed, fields == nil {
            throw TOONDecodingError.invalidHeader(
                "A keyed header requires a field list: \(content)"
            )
        }

        return ArrayHeader(
            key: key,
            count: count,
            delimiter: delimiter,
            fields: fields,
            isKeyed: isKeyed
        )
    }

    private func findClosingQuote(in str: Substring) -> String.Index? {
        var escaped = false
        var index = str.index(after: str.startIndex)  // Skip opening quote

        while index < str.endIndex {
            let char = str[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                return index
            }
            index = str.index(after: index)
        }

        return nil
    }

    /// The position of the brace that closes the field list that starts after
    /// the opening brace. A brace inside a quoted name is content.
    private func findMatchingBrace(in text: Substring) -> Substring.Index? {
        var depth = 0
        var inQuotes = false
        var escaped = false
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inQuotes.toggle()
            } else if !inQuotes {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    if depth == 0 {
                        return index
                    }
                    depth -= 1
                }
            }
            index = text.index(after: index)
        }

        return nil
    }

    /// Splits a field list, and recurses into a nested field group.
    ///
    /// Specification 9.3 gives a field the shape `name` or `name{sub,sub}`.
    /// The separator inside a group is the active delimiter, the same as
    /// outside it. A brace or a delimiter inside a quoted name is content.
    ///
    /// A group nests without a cap in the specification, so `depth` counts the
    /// levels against ``TOONDecoder/DecodingLimits/maxDepth``. The recursion
    /// runs on the stack, and an input of 10,000 levels stops the process
    /// without the check.
    private func parseFieldsList(
        _ fieldsStr: String,
        delimiter: String,
        depth: Int = 0
    ) throws -> [FieldNode] {
        if depth > limits.maxDepth {
            throw TOONDecodingError.depthLimitExceeded(depth: depth, limit: limits.maxDepth)
        }

        var fields: [FieldNode] = []
        var current = ""
        var inQuotes = false
        var escaped = false
        var braceDepth = 0

        for char in fieldsStr {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                current.append(char)
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
                continue
            }

            if !inQuotes {
                if char == "{" {
                    braceDepth += 1
                } else if char == "}" {
                    braceDepth -= 1
                    guard braceDepth >= 0 else {
                        throw TOONDecodingError.invalidHeader(
                            "Unbalanced '}' in the field list: \(fieldsStr)"
                        )
                    }
                }

                if braceDepth == 0, String(char) == delimiter {
                    try fields.append(parseField(current, delimiter: delimiter, depth: depth))
                    current = ""
                    continue
                }
            }

            current.append(char)
        }

        guard braceDepth == 0 else {
            throw TOONDecodingError.invalidHeader(
                "Unterminated field group in the field list: \(fieldsStr)"
            )
        }

        if !current.isEmpty {
            try fields.append(parseField(current, delimiter: delimiter, depth: depth))
        }

        return fields
    }

    /// Reads one entry of a field list, which may carry a nested group.
    private func parseField(_ field: String, delimiter: String, depth: Int) throws -> FieldNode {
        let trimmed = field.trimmingSpaces()

        guard let braceIndex = indexOfGroupBrace(in: trimmed) else {
            return FieldNode(name: try parseFieldName(trimmed))
        }

        guard trimmed.hasSuffix("}") else {
            throw TOONDecodingError.invalidHeader("Unterminated field group in: \(field)")
        }

        let name = String(trimmed[..<braceIndex])
        let innerStart = trimmed.index(after: braceIndex)
        let inner = String(trimmed[innerStart ..< trimmed.index(before: trimmed.endIndex)])

        let children = try parseFieldsList(inner, delimiter: delimiter, depth: depth + 1)
        guard !children.isEmpty else {
            throw TOONDecodingError.invalidHeader("Empty field group in: \(field)")
        }

        return FieldNode(name: try parseFieldName(name), children: children)
    }

    /// The position of the brace that opens a nested group, skipping a brace
    /// that sits inside a quoted name.
    private func indexOfGroupBrace(in field: String) -> String.Index? {
        var inQuotes = false
        var escaped = false
        var index = field.startIndex

        while index < field.endIndex {
            let char = field[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inQuotes.toggle()
            } else if char == "{", !inQuotes {
                return index
            }
            index = field.index(after: index)
        }

        return nil
    }

    private func parseFieldName(_ field: String) throws -> String {
        let trimmed = field.trimmingSpaces()
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            let inner = String(trimmed.dropFirst().dropLast())
            return try unescapeString(inner)
        }
        return trimmed
    }

    /// Builds one row object by walking the field tree against the cells.
    ///
    /// Specification 9.3 maps the cells to the leaves in depth-first order.
    /// Specification 14.1 gives two rules for non-strict mode. A leaf with no
    /// remaining cell is absent from the object, and is not null. A surplus
    /// cell contributes nothing.
    private func materializeRow(fields: [FieldNode], cells: [Value], cursor: inout Int) -> Value {
        var values: ObjectStorage = [:]

        for field in fields {
            let value: Value
            if let children = field.children {
                let before = cursor
                let nested = materializeRow(fields: children, cells: cells, cursor: &cursor)
                if cursor == before, case let .object(inner) = nested, inner.isEmpty {
                    continue
                }
                value = nested
            } else {
                guard cursor < cells.count else { continue }
                value = cells[cursor]
                cursor += 1
            }

            // Specification 14.3 resolves a duplicate name by last write wins.
            // The name keeps the position of its first appearance.
            values[field.name] = value
        }

        return .object(values)
    }

    private func parseArrayAtCurrentLine(depth: Int, key _: String?) throws -> Value {
        guard let line = consumeLine() else {
            throw TOONDecodingError.invalidFormat("Expected array header")
        }

        let (_, content) = trimIndentation(line)
        let header = try parseArrayHeader(String(content))
        return try parseArrayContent(header: header, atDepth: depth)
    }

    private func parseArrayContent(header: ArrayHeader, atDepth depth: Int) throws -> Value {
        // Check array length limit
        if header.count > limits.maxArrayLength {
            throw TOONDecodingError.arrayLengthLimitExceeded(length: header.count, limit: limits.maxArrayLength)
        }

        // Specification 6 forbids content after the colon of a header that
        // carries a field list: the rows live on the lines below it.
        if strict, header.fields != nil, headerCarriesInlineContent() {
            throw TOONDecodingError.invalidHeader(
                "Content after the colon of a header that carries a field list, at line "
                    + "\(sourceLine(currentLine - 1))"
            )
        }

        // A keyed header describes an object, not an array (specification 9.5).
        if header.isKeyed {
            return try parseKeyedEntryRows(header: header, atDepth: depth)
        }

        // Check for inline values after header
        // For example: tags[3]: a,b,c

        // Re-parse to get the full line with potential inline values
        let headerLine = lines[currentLine - 1]
        let (_, content) = trimIndentation(headerLine)
        let contentStr = String(content)

        // Find where the header ends (after the colon)
        if let colonIndex = headerColonIndex(in: contentStr[...]) {
            let afterColon = contentStr[contentStr.index(after: colonIndex)...]
            let inlineValues = afterColon.trimmingLeadingSpace()

            if !inlineValues.isEmpty {
                // Inline primitive array
                let values = try parseDelimitedValues(String(inlineValues), delimiter: header.delimiter)
                if values.count != header.count {
                    throw TOONDecodingError.countMismatch(
                        expected: header.count,
                        actual: values.count,
                        line: lastReadSourceLine
                    )
                }
                return .array(values)
            }
        }

        // No inline values - parse expanded content
        if header.count == 0 {
            return .array([])
        }

        var items: [Value] = []

        if let fields = header.fields {
            // Tabular format
            items = try parseTabularRows(
                count: header.count,
                fields: fields,
                delimiter: header.delimiter,
                atDepth: depth
            )
        } else {
            // List format or array of arrays
            items = try parseListItems(count: header.count, delimiter: header.delimiter, atDepth: depth)
        }

        // The readers above already apply the length rule of specification
        // 14.1, which is a strict-mode check and never truncates the scope.
        return .array(items)
    }

    /// Whether the header line that was just consumed carries content after
    /// its final colon.
    private func headerCarriesInlineContent() -> Bool {
        guard currentLine > 0, currentLine - 1 < lines.count else { return false }
        let (_, content) = trimIndentation(lines[currentLine - 1])
        guard let colonIndex = headerColonIndex(in: content) else { return false }
        let afterColon = content[content.index(after: colonIndex)...]
        return !afterColon.trimmingLeadingSpace().isEmpty
    }

    /// Reads the entry rows of a keyed tabular scope (specification 9.5).
    ///
    /// Each row splits in two steps. First at its first unquoted colon: the
    /// token before the colon is the entry key. Then the remainder splits on
    /// the active delimiter into cells, and decodes exactly as a row of
    /// section 9.3, so a nested field group materializes recursively.
    ///
    /// `alice: []` is one cell that decodes to the string `[]`; the
    /// empty-array form of section 9.1 does not apply inside an entry row.
    private func parseKeyedEntryRows(header: ArrayHeader, atDepth depth: Int) throws -> Value {
        guard let fields = header.fields else {
            throw TOONDecodingError.invalidHeader("A keyed header requires a field list")
        }

        var values: ObjectStorage = [:]
        let expectedDepth = depth + 1
        let width = fields.leafCount

        // Specification 14.1 states that a declared length never terminates or
        // truncates a scope. The loop therefore reads to the end of the scope,
        // then checks the length.
        while true {
            try skipBlankLines(insideScopeAtDepth: expectedDepth, hasElement: !values.isEmpty)

            guard let line = peekLine(), !line.isEmpty else { break }

            let (lineDepth, content) = trimIndentation(line)
            if lineDepth != expectedDepth {
                break
            }

            _ = consumeLine()

            // Specification 9.5: a line at entry depth without an unquoted
            // colon is an error in strict mode, and may be skipped otherwise.
            guard let colonIndex = findUnquotedColon(in: content) else {
                if strict {
                    throw TOONDecodingError.invalidFormat(
                        "An entry row of a keyed scope needs a colon, at line "
                            + "\(lastReadSourceLine)"
                    )
                }
                continue
            }

            let entryKey = try parseFieldName(String(content[..<colonIndex]))
            let rest = content[content.index(after: colonIndex)...].trimmingLeadingSpace()
            let cells = try parseDelimitedValues(String(rest), delimiter: header.delimiter)

            // Specification 14.1 makes a width mismatch an error in strict
            // mode only. Outside strict mode ``materializeRow`` keeps a leaf
            // with no cell absent, and drops a surplus cell.
            if cells.count != width, strict {
                throw TOONDecodingError.fieldCountMismatch(
                    expected: width,
                    actual: cells.count,
                    line: lastReadSourceLine
                )
            }

            var cursor = 0
            let entry = materializeRow(fields: fields, cells: cells, cursor: &cursor)

            try storeKey(entryKey, value: entry, into: &values)
        }

        if strict, values.count != header.count {
            throw TOONDecodingError.countMismatch(
                expected: header.count,
                actual: values.count,
                line: lastReadSourceLine
            )
        }

        return .object(values)
    }

    /// The position of the first colon that sits outside a quoted span.
    private func findUnquotedColon(in text: Substring) -> Substring.Index? {
        var inQuotes = false
        var escaped = false
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inQuotes.toggle()
            } else if char == ":", !inQuotes {
                return index
            }
            index = text.index(after: index)
        }

        return nil
    }

    private func parseTabularRows(
        count: Int,
        fields: [FieldNode],
        delimiter: String,
        atDepth depth: Int
    ) throws -> [Value] {
        var rows: [Value] = []
        let expectedDepth = depth + 1

        // Specification 14.1 states that a declared length never terminates or
        // truncates a scope. The scope ends where the depth decreases, and the
        // length is a check afterwards.
        while true {
            try skipBlankLines(insideScopeAtDepth: expectedDepth, hasElement: !rows.isEmpty)

            guard let line = peekLine(), !line.isEmpty else { break }

            let (lineDepth, content) = trimIndentation(line)

            if lineDepth < expectedDepth {
                break
            }

            if lineDepth > expectedDepth {
                throw TOONDecodingError.invalidIndentation(
                    line: sourceLine(currentLine),
                    message: "Expected indentation depth \(expectedDepth), got \(lineDepth)"
                )
            }

            _ = consumeLine()

            let cells = try parseDelimitedValues(String(content), delimiter: delimiter)

            // The width of a row is the number of leaves, not the number of
            // entries of the field list: a nested group spans several cells.
            let width = fields.leafCount
            // Specification 14.1 makes a width mismatch an error in strict
            // mode only. Outside strict mode ``materializeRow`` keeps a leaf
            // with no cell absent, and drops a surplus cell.
            if cells.count != width, strict {
                throw TOONDecodingError.fieldCountMismatch(
                    expected: width,
                    actual: cells.count,
                    line: lastReadSourceLine
                )
            }

            var cursor = 0
            rows.append(materializeRow(fields: fields, cells: cells, cursor: &cursor))
        }

        if strict, rows.count != count {
            throw TOONDecodingError.countMismatch(
                expected: count,
                actual: rows.count,
                line: lastReadSourceLine
            )
        }

        return rows
    }

    private func parseListItems(count: Int, delimiter: String, atDepth depth: Int) throws -> [Value] {
        var items: [Value] = []
        let expectedDepth = depth + 1

        // Specification 14.1 states that a declared length never terminates or
        // truncates a scope. The loop therefore reads to the end of the scope,
        // then checks the length.
        while true {
            try skipBlankLines(insideScopeAtDepth: expectedDepth, hasElement: !items.isEmpty)

            guard let line = peekLine(), !line.isEmpty else { break }

            let (lineDepth, content) = trimIndentation(line)

            if lineDepth < expectedDepth {
                break
            }

            if lineDepth > expectedDepth {
                throw TOONDecodingError.invalidIndentation(
                    line: sourceLine(currentLine),
                    message: "Expected indentation depth \(expectedDepth), got \(lineDepth)"
                )
            }

            // A line of the scope that is not a list item ends it. The bare
            // marker of section 9.4 is a hyphen with nothing after it.
            guard content.hasPrefix("- ") || content == "-" else { break }

            _ = consumeLine()

            let itemContent = content.hasPrefix("- ") ? String(content.dropFirst(2)) : ""
            let item = try parseListItemContent(itemContent, atDepth: expectedDepth, delimiter: delimiter)
            items.append(item)
        }

        if strict, items.count != count {
            throw TOONDecodingError.countMismatch(
                expected: count,
                actual: items.count,
                line: lastReadSourceLine
            )
        }

        return items
    }

    private func parseListItemContent(_ content: String, atDepth depth: Int, delimiter _: String) throws -> Value {
        // The bare marker of specification 9.4: a hyphen with nothing after it
        // is an empty object.
        if content.isEmpty {
            return .object([:])
        }

        // Specification 9.2 gives the literal token `[]` on a list-item line
        // the meaning of an empty array.
        if content == "[]" {
            return .array([])
        }

        // Check for array header WITHOUT key: - [N]: a,b,c
        // This returns a bare array, not an object with an array field
        if content.hasPrefix("["), let header = try parseHeaderIfPresent(content) {
            // Specification 6 allows a keyless header as a list item only
            // without a field list.
            if header.fields != nil, strict {
                throw TOONDecodingError.invalidHeader(
                    "A keyless header that carries a field list is not allowed as a list item: "
                        + content
                )
            }
            return try parseArrayContent(header: header, atDepth: depth)
        }

        // Check for key: value on same line (may be key[N]: values for array)
        if let colonIndex = findKeyValueSeparator(in: content) {
            let keyPart = String(content[..<colonIndex])
            let key = try parseKey(keyPart)

            let afterColon = content.index(after: colonIndex)
            let valuePart = String(content[afterColon...]).trimmingLeadingSpace()

            var objectValues: ObjectStorage = [:]

            if valuePart.isEmpty {
                // A header on the hyphen line describes the first field of the
                // list-item object. That field sits one level below the hyphen
                // line, so its rows sit two levels below it (specification 10).
                if let header = try parseHeaderIfPresent(content),
                    let headerKey = header.key
                {
                    objectValues[headerKey] = try parseArrayContent(
                        header: header,
                        atDepth: depth + 1
                    )
                } else {
                    // The first field sits one level below the hyphen line, so
                    // its own content sits two levels below it (section 10).
                    let nestedValue = try parseNestedValue(atDepth: depth + 2)
                    objectValues[key] = nestedValue
                }
            } else {
                // Check if the key is an array header (like nums[3])
                // The full string would be "nums[3]: 1,2,3"
                if let header = try parseHeaderIfPresent(content) {
                    // Parse as array with the key
                    let array = try parseArrayContent(header: header, atDepth: depth)
                    let arrayKey = header.key ?? key
                    objectValues[arrayKey] = array
                } else {
                    // Inline primitive value
                    objectValues[key] = try parseValueInValuePosition(valuePart)
                }
            }

            // Parse additional fields at depth + 1. The fields of a list-item
            // object are the content of its scope, so a blank line among them
            // is interior and section 12 rejects it.
            while let nextLine = peekLine() {
                if nextLine.isEmpty {
                    // Leave the blank lines for the enclosing scope when they
                    // end this item, so that the list itself judges them.
                    guard let nextDepth = depthOfNextContentLine(), nextDepth >= depth + 1
                    else { break }
                    try skipBlankLines(insideScopeAtDepth: depth + 1, hasElement: true)
                    continue
                }

                let (nextDepth, nextContent) = trimIndentation(nextLine)

                if nextDepth != depth + 1 {
                    break
                }

                // Check if it's another list item (shouldn't be at this depth)
                if nextContent.hasPrefix("- ") {
                    break
                }

                _ = consumeLine()

                let (nextKey, nextValue) = try parseKeyValuePair(String(nextContent), atDepth: depth + 1)
                try storeKey(nextKey, value: nextValue, into: &objectValues)
            }

            return .object(objectValues)
        }

        // Single primitive value
        return try parsePrimitiveValue(content)
    }

    // MARK: - Value Parsing

    private func parseDelimitedValues(_ content: String, delimiter: String) throws -> [Value] {
        var values: [Value] = []
        var current = ""
        var inQuotes = false
        var escaped = false

        for char in content {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                current.append(char)
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
                continue
            }

            if !inQuotes, String(char) == delimiter {
                try values.append(parsePrimitiveValue(current.trimmingSpaces()))
                current = ""
                continue
            }

            current.append(char)
        }

        // Handle last value
        let trimmed = current.trimmingSpaces()
        if !trimmed.isEmpty || !values.isEmpty {
            try values.append(parsePrimitiveValue(trimmed))
        }

        return values
    }

    /// Reads a value that sits after a key-value colon.
    ///
    /// Specification 4 gives the literal token `[]` the meaning of an empty
    /// array in a value position. Inside an inline array or a tabular cell
    /// the same token is the string `[]`.
    ///
    /// The other two value positions read the token on their own: the root
    /// in ``parse()``, and a list-item line in ``parseListItemContent(_:atDepth:delimiter:)``.
    private func parseValueInValuePosition(_ content: String) throws -> Value {
        if content.trimmingSpaces() == "[]" {
            return .array([])
        }
        return try parsePrimitiveValue(content)
    }

    private func parsePrimitiveValue(_ content: String) throws -> Value {
        let trimmed = content.trimmingSpaces()

        if trimmed.isEmpty {
            return .string("")
        }

        // Quoted string. Specification 7.4 states that a token which begins
        // with a quote must end at its closing quote. The rule holds in both
        // modes. A missing quote is an error, and so is any character after the
        // closing one.
        if trimmed.hasPrefix("\"") {
            guard let closing = findClosingQuote(in: trimmed[...]) else {
                throw TOONDecodingError.invalidFormat(
                    "Unterminated quoted value at line \(lastReadSourceLine)"
                )
            }
            guard trimmed.index(after: closing) == trimmed.endIndex else {
                throw TOONDecodingError.invalidFormat(
                    "Characters after the closing quote at line \(lastReadSourceLine)"
                )
            }
            let inner = String(trimmed[trimmed.index(after: trimmed.startIndex) ..< closing])
            return try .string(unescapeString(inner))
        }

        // Boolean
        if trimmed == "true" {
            return .bool(true)
        }
        if trimmed == "false" {
            return .bool(false)
        }

        // Null
        if trimmed == "null" {
            return .null
        }

        // Number, per the normative grammar of specification 4. Anything that
        // the grammar rejects is a string.
        if let number = NumberGrammar.value(of: trimmed) {
            return number
        }

        return .string(trimmed)
    }

    // MARK: - String Handling

    /// Unescapes a quoted span, per TOON specification 7.1.
    ///
    /// The table has five short forms plus `\uXXXX`, whose hexadecimal digits
    /// are case-insensitive. A surrogate escape is rejected. Section 7.1 says
    /// that a lone surrogate MUST error. It also says that a supplementary
    /// scalar MUST arrive as literal UTF-8, not as a surrogate pair. Any other
    /// escape, and a trailing backslash, are errors.
    private func unescapeString(_ str: String) throws -> String {
        var result = String.UnicodeScalarView()
        let scalars = Array(str.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]
            index += 1

            guard scalar == "\\" else {
                result.append(scalar)
                continue
            }

            guard index < scalars.count else {
                throw TOONDecodingError.invalidEscapeSequence("Trailing backslash in string")
            }

            let marker = scalars[index]
            index += 1

            switch marker {
            case "\\": result.append("\\")
            case "\"": result.append("\"")
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "t": result.append("\t")
            case "u":
                guard index + 4 <= scalars.count else {
                    throw TOONDecodingError.invalidEscapeSequence(
                        "A \\u escape needs four hexadecimal digits"
                    )
                }
                var code: UInt32 = 0
                for offset in 0 ..< 4 {
                    guard let digit = scalars[index + offset].hexDigitValue else {
                        throw TOONDecodingError.invalidEscapeSequence(
                            "A \\u escape needs four hexadecimal digits"
                        )
                    }
                    code = code << 4 | UInt32(digit)
                }
                index += 4

                guard let decoded = Unicode.Scalar(code) else {
                    throw TOONDecodingError.invalidEscapeSequence(
                        "A surrogate code point is not allowed in a \\u escape"
                    )
                }
                result.append(decoded)
            default:
                throw TOONDecodingError.invalidEscapeSequence(
                    "Invalid escape sequence: \\\(marker)"
                )
            }
        }

        return String(result)
    }

    // MARK: - Path Expansion

    private func expandDottedKey(
        _ key: String,
        value: Value,
        into values: inout ObjectStorage
    ) throws {
        let segments = key.split(separator: ".").map(String.init)

        guard segments.count > 1 else {
            values[key] = value
            return
        }

        let firstKey = segments[0]

        // Merge the value into the nested structure
        values[firstKey] = try mergeValueAtPath(
            into: values[firstKey],
            segments: Array(segments.dropFirst()),
            value: value
        )
    }

    private func mergeValueAtPath(
        into existing: Value?,
        segments: [String],
        value: Value
    ) throws -> Value {
        guard let segment = segments.first else {
            return value
        }

        let remainingSegments = Array(segments.dropFirst())

        // Get or create object at current level
        var objectValues: ObjectStorage

        if let existing = existing {
            guard case let .object(vals) = existing else {
                throw TOONDecodingError.pathCollision(path: segment, line: lastReadSourceLine)
            }
            objectValues = vals
        } else {
            objectValues = [:]
        }

        // Recursively merge
        objectValues[segment] = try mergeValueAtPath(
            into: objectValues[segment],
            segments: remainingSegments,
            value: value
        )

        return .object(objectValues)
    }
}

// MARK: - Internal Decoder

extension TOONDecoder {
    /// Internal decoder implementation that conforms to the `Decoder` protocol.
    private final class Decoder: Swift.Decoder {
        let value: Value
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        init(value: Value, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.value = value
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey {
            guard let values = value.objectValue else {
                throw TOONDecodingError.typeMismatch(expected: "object", actual: value.typeName)
            }
            let container = KeyedContainer<Key>(
                values: values,
                codingPath: codingPath,
                userInfo: userInfo
            )
            return KeyedDecodingContainer(container)
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            guard let array = value.arrayValue else {
                throw TOONDecodingError.typeMismatch(expected: "array", actual: value.typeName)
            }
            return UnkeyedContainer(values: array, codingPath: codingPath, userInfo: userInfo)
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return SingleValueContainer(value: value, codingPath: codingPath, userInfo: userInfo)
        }
    }
}

// MARK: - Keyed Decoding Container

extension TOONDecoder {
    private final class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let values: ObjectStorage
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        var allKeys: [Key] {
            values.keys.compactMap { Key(stringValue: $0) }
        }

        init(
            values: ObjectStorage,
            codingPath: [CodingKey],
            userInfo: [CodingUserInfoKey: Any]
        ) {
            self.values = values
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func contains(_ key: Key) -> Bool {
            values[key.stringValue] != nil
        }

        private func getValue(forKey key: Key) throws -> Value {
            guard let value = values[key.stringValue] else {
                throw TOONDecodingError.keyNotFound(key.stringValue)
            }
            return value
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            guard let value = values[key.stringValue] else {
                throw TOONDecodingError.keyNotFound(key.stringValue)
            }
            return value.isNull
        }

        func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
            let value = try getValue(forKey: key)
            guard let boolValue = value.boolValue else {
                throw TOONDecodingError.typeMismatch(expected: "bool", actual: value.typeName)
            }
            return boolValue
        }

        func decode(_: String.Type, forKey key: Key) throws -> String {
            let value = try getValue(forKey: key)
            guard let stringValue = value.stringValue else {
                throw TOONDecodingError.typeMismatch(expected: "string", actual: value.typeName)
            }
            return stringValue
        }

        func decode(_: Double.Type, forKey key: Key) throws -> Double {
            let value = try getValue(forKey: key)
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "double", actual: value.typeName)
            }
            return doubleValue
        }

        func decode(_: Float.Type, forKey key: Key) throws -> Float {
            let value = try getValue(forKey: key)
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "float", actual: value.typeName)
            }
            return try narrowToFloat(doubleValue)
        }

        func decode(_: Int.Type, forKey key: Key) throws -> Int {
            try decodeInt(from: getValue(forKey: key))
        }

        func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
            try decodeInt8(from: getValue(forKey: key))
        }

        func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
            try decodeInt16(from: getValue(forKey: key))
        }

        func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
            try decodeInt32(from: getValue(forKey: key))
        }

        func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
            let value = try getValue(forKey: key)
            guard let intValue = value.intValue else {
                throw TOONDecodingError.typeMismatch(expected: "int64", actual: value.typeName)
            }
            return intValue
        }

        func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
            try decodeUInt(from: getValue(forKey: key))
        }

        func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try decodeUInt8(from: getValue(forKey: key))
        }

        func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try decodeUInt16(from: getValue(forKey: key))
        }

        func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try decodeUInt32(from: getValue(forKey: key))
        }

        func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try decodeUInt64(from: getValue(forKey: key))
        }

        func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable {
            let value = try getValue(forKey: key)

            // Handle special types
            if T.self == Date.self {
                return try decodeDate(from: value) as! T
            }

            if T.self == URL.self {
                return try decodeURL(from: value) as! T
            }

            if T.self == Data.self {
                return try decodeData(from: value) as! T
            }

            let decoder = Decoder(
                value: value,
                codingPath: codingPath + [key],
                userInfo: userInfo
            )
            return try T(from: decoder)
        }

        func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            let value = try getValue(forKey: key)
            guard let values = value.objectValue else {
                throw TOONDecodingError.typeMismatch(expected: "object", actual: value.typeName)
            }
            let container = KeyedContainer<NestedKey>(
                values: values,
                codingPath: codingPath + [key],
                userInfo: userInfo
            )
            return KeyedDecodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            let value = try getValue(forKey: key)
            guard let array = value.arrayValue else {
                throw TOONDecodingError.typeMismatch(expected: "array", actual: value.typeName)
            }
            return UnkeyedContainer(values: array, codingPath: codingPath + [key], userInfo: userInfo)
        }

        func superDecoder() throws -> Swift.Decoder {
            let value = values["super"] ?? .null
            return Decoder(value: value, codingPath: codingPath, userInfo: userInfo)
        }

        func superDecoder(forKey key: Key) throws -> Swift.Decoder {
            let value = try getValue(forKey: key)
            return Decoder(value: value, codingPath: codingPath + [key], userInfo: userInfo)
        }
    }
}

// MARK: - Unkeyed Decoding Container

extension TOONDecoder {
    private final class UnkeyedContainer: UnkeyedDecodingContainer {
        let values: [Value]
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        var count: Int? { values.count }
        var isAtEnd: Bool { currentIndex >= values.count }
        var currentIndex: Int = 0

        init(values: [Value], codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.values = values
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        private func getCurrentValue() throws -> Value {
            guard currentIndex < values.count else {
                throw TOONDecodingError.dataCorrupted("No more values in array")
            }
            let value = values[currentIndex]
            currentIndex += 1
            return value
        }

        func decodeNil() throws -> Bool {
            guard currentIndex < values.count else {
                throw TOONDecodingError.dataCorrupted("No more values in array")
            }
            if values[currentIndex].isNull {
                currentIndex += 1
                return true
            }
            return false
        }

        func decode(_: Bool.Type) throws -> Bool {
            let value = try getCurrentValue()
            guard let boolValue = value.boolValue else {
                throw TOONDecodingError.typeMismatch(expected: "bool", actual: value.typeName)
            }
            return boolValue
        }

        func decode(_: String.Type) throws -> String {
            let value = try getCurrentValue()
            guard let stringValue = value.stringValue else {
                throw TOONDecodingError.typeMismatch(expected: "string", actual: value.typeName)
            }
            return stringValue
        }

        func decode(_: Double.Type) throws -> Double {
            let value = try getCurrentValue()
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "double", actual: value.typeName)
            }
            return doubleValue
        }

        func decode(_: Float.Type) throws -> Float {
            let value = try getCurrentValue()
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "float", actual: value.typeName)
            }
            return try narrowToFloat(doubleValue)
        }

        func decode(_: Int.Type) throws -> Int {
            try decodeInt(from: getCurrentValue())
        }

        func decode(_: Int8.Type) throws -> Int8 {
            try decodeInt8(from: getCurrentValue())
        }

        func decode(_: Int16.Type) throws -> Int16 {
            try decodeInt16(from: getCurrentValue())
        }

        func decode(_: Int32.Type) throws -> Int32 {
            try decodeInt32(from: getCurrentValue())
        }

        func decode(_: Int64.Type) throws -> Int64 {
            let value = try getCurrentValue()
            guard let intValue = value.intValue else {
                throw TOONDecodingError.typeMismatch(expected: "int64", actual: value.typeName)
            }
            return intValue
        }

        func decode(_: UInt.Type) throws -> UInt {
            try decodeUInt(from: getCurrentValue())
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            try decodeUInt8(from: getCurrentValue())
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            try decodeUInt16(from: getCurrentValue())
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            try decodeUInt32(from: getCurrentValue())
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            try decodeUInt64(from: getCurrentValue())
        }

        func decode<T>(_: T.Type) throws -> T where T: Decodable {
            let value = try getCurrentValue()

            // Handle special types
            if T.self == Date.self {
                return try decodeDate(from: value) as! T
            }

            if T.self == URL.self {
                return try decodeURL(from: value) as! T
            }

            if T.self == Data.self {
                return try decodeData(from: value) as! T
            }

            let decoder = Decoder(
                value: value,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
            return try T(from: decoder)
        }

        func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey {
            let value = try getCurrentValue()
            guard let values = value.objectValue else {
                throw TOONDecodingError.typeMismatch(expected: "object", actual: value.typeName)
            }
            let container = KeyedContainer<NestedKey>(
                values: values,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
            return KeyedDecodingContainer(container)
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let value = try getCurrentValue()
            guard let array = value.arrayValue else {
                throw TOONDecodingError.typeMismatch(expected: "array", actual: value.typeName)
            }
            return UnkeyedContainer(
                values: array,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
        }

        func superDecoder() throws -> Swift.Decoder {
            let value = try getCurrentValue()
            return Decoder(
                value: value,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Single Value Decoding Container

extension TOONDecoder {
    private final class SingleValueContainer: SingleValueDecodingContainer {
        let value: Value
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        init(value: Value, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.value = value
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func decodeNil() -> Bool {
            value.isNull
        }

        func decode(_: Bool.Type) throws -> Bool {
            guard let boolValue = value.boolValue else {
                throw TOONDecodingError.typeMismatch(expected: "bool", actual: value.typeName)
            }
            return boolValue
        }

        func decode(_: String.Type) throws -> String {
            guard let stringValue = value.stringValue else {
                throw TOONDecodingError.typeMismatch(expected: "string", actual: value.typeName)
            }
            return stringValue
        }

        func decode(_: Double.Type) throws -> Double {
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "double", actual: value.typeName)
            }
            return doubleValue
        }

        func decode(_: Float.Type) throws -> Float {
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "float", actual: value.typeName)
            }
            return try narrowToFloat(doubleValue)
        }

        func decode(_: Int.Type) throws -> Int {
            try decodeInt(from: value)
        }

        func decode(_: Int8.Type) throws -> Int8 {
            try decodeInt8(from: value)
        }

        func decode(_: Int16.Type) throws -> Int16 {
            try decodeInt16(from: value)
        }

        func decode(_: Int32.Type) throws -> Int32 {
            try decodeInt32(from: value)
        }

        func decode(_: Int64.Type) throws -> Int64 {
            guard let intValue = value.intValue else {
                throw TOONDecodingError.typeMismatch(expected: "int64", actual: value.typeName)
            }
            return intValue
        }

        func decode(_: UInt.Type) throws -> UInt {
            try decodeUInt(from: value)
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            try decodeUInt8(from: value)
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            try decodeUInt16(from: value)
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            try decodeUInt32(from: value)
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            try decodeUInt64(from: value)
        }

        func decode<T>(_: T.Type) throws -> T where T: Decodable {
            // Handle special types
            if T.self == Date.self {
                return try decodeDate(from: value) as! T
            }

            if T.self == URL.self {
                return try decodeURL(from: value) as! T
            }

            if T.self == Data.self {
                return try decodeData(from: value) as! T
            }

            let decoder = Decoder(value: value, codingPath: codingPath, userInfo: userInfo)
            return try T(from: decoder)
        }
    }
}

// MARK: - Decoding Helpers

// ISO8601DateFormatter is not Sendable, so we create a new instance per decode
// This is thread-safe and avoids shared mutable state
private func decodeDate(from value: Value) throws -> Date {
    guard let stringValue = value.stringValue else {
        throw TOONDecodingError.typeMismatch(expected: "date string", actual: value.typeName)
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: stringValue) else {
        throw TOONDecodingError.dataCorrupted("Invalid date format: \(stringValue)")
    }
    return date
}

private func decodeURL(from value: Value) throws -> URL {
    guard let stringValue = value.stringValue else {
        throw TOONDecodingError.typeMismatch(expected: "URL string", actual: value.typeName)
    }
    guard !stringValue.isEmpty, let url = URL(string: stringValue) else {
        throw TOONDecodingError.dataCorrupted("Invalid URL: \(stringValue)")
    }
    return url
}

private func decodeData(from value: Value) throws -> Data {
    guard let stringValue = value.stringValue else {
        throw TOONDecodingError.typeMismatch(expected: "base64 string", actual: value.typeName)
    }
    guard let data = Data(base64Encoded: stringValue) else {
        throw TOONDecodingError.dataCorrupted("Invalid base64 data: \(stringValue)")
    }
    return data
}

private func decodeInt8(from value: Value) throws -> Int8 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int8", actual: value.typeName)
    }
    guard let result = Int8(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int8")
    }
    return result
}

private func decodeInt16(from value: Value) throws -> Int16 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int16", actual: value.typeName)
    }
    guard let result = Int16(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int16")
    }
    return result
}

private func decodeInt32(from value: Value) throws -> Int32 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int32", actual: value.typeName)
    }
    guard let result = Int32(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int32")
    }
    return result
}

private func decodeInt(from value: Value) throws -> Int {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int", actual: value.typeName)
    }
    guard let result = Int(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int")
    }
    return result
}

private func decodeUInt(from value: Value) throws -> UInt {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint", actual: value.typeName)
    }
    guard let result = UInt(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt")
    }
    return result
}

private func decodeUInt8(from value: Value) throws -> UInt8 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint8", actual: value.typeName)
    }
    guard let result = UInt8(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt8")
    }
    return result
}

private func decodeUInt16(from value: Value) throws -> UInt16 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint16", actual: value.typeName)
    }
    guard let result = UInt16(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt16")
    }
    return result
}

private func decodeUInt32(from value: Value) throws -> UInt32 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint32", actual: value.typeName)
    }
    guard let result = UInt32(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt32")
    }
    return result
}

/// Converts a `Double` to a `Float`, and reports a value that does not fit.
///
/// `Float(_:)` gives an infinity for a finite `Double` that is too large. The
/// integer helpers all use `exactly:` and report such a value, so the floating
/// point path follows them. `Float(exactly:)` is the wrong tool here: it
/// rejects every `Double` that a `Float` cannot hold exactly, among them 0.1.
private func narrowToFloat(_ value: Double) throws -> Float {
    let result = Float(value)
    guard result.isFinite || !value.isFinite else {
        throw TOONDecodingError.dataCorrupted("Value \(value) does not fit in Float")
    }
    return result
}

private func decodeUInt64(from value: Value) throws -> UInt64 {
    // Try integer path first
    if let intValue = value.intValue {
        guard let result = UInt64(exactly: intValue) else {
            throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt64")
        }
        return result
    }

    // A UInt64 above Int64.max stays a string in the model, so read it back
    // from there. UInt64(_:) has a wider grammar than section 4: it accepts a
    // leading plus. The token must match the grammar first, or `+5`, which
    // section 4 makes a string, would decode as the number 5.
    if let stringValue = value.stringValue,
        NumberGrammar.form(of: stringValue) == .integer,
        let result = UInt64(stringValue)
    {
        return result
    }

    throw TOONDecodingError.typeMismatch(expected: "uint64", actual: value.typeName)
}

// MARK: -

private extension String {
    func trimmingLeadingSpace() -> String {
        guard let first = first, first == " " else { return self }
        return String(dropFirst())
    }

    var isValidDottedPath: Bool {
        // Valid dotted path must have segments that are valid identifiers
        let segments = split(separator: ".")
        guard segments.count > 1 else { return false }
        return segments.allSatisfy { $0.isValidIdentifier }
    }
}

private extension Substring {
    func trimmingLeadingSpace() -> Substring {
        guard let first = first, first == " " else { return self }
        return dropFirst()
    }

    var isValidIdentifier: Bool {
        guard let first = first else { return false }
        guard first.isLetter || first == "_" else { return false }
        return dropFirst().allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

extension StringProtocol {
    /// Removes the leading and trailing U+0020, and nothing else.
    ///
    /// TOON specification 12 states that token trimming takes exactly U+0020.
    /// Any other whitespace is part of the token, among them a no-break space
    /// and a tab outside its delimiter role. CharacterSet.whitespaces covers
    /// every Unicode space separator, so it trims too much.
    fileprivate func trimmingSpaces() -> String {
        var scalars = Substring.UnicodeScalarView(unicodeScalars)
        while scalars.first == " " {
            scalars = scalars.dropFirst()
        }
        while scalars.last == " " {
            scalars = scalars.dropLast()
        }
        return String(String.UnicodeScalarView(scalars))
    }
}

extension Character {
    /// `true` for U+0030 to U+0039 only.
    fileprivate var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}

extension Unicode.Scalar {
    /// The value of an ASCII hexadecimal digit, or `nil`.
    fileprivate var hexDigitValue: Int? {
        switch self {
        case "0" ... "9": return Int(value - 0x30)
        case "a" ... "f": return Int(value - 0x61) + 10
        case "A" ... "F": return Int(value - 0x41) + 10
        default: return nil
        }
    }
}
