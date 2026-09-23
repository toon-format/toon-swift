import Foundation

/// An encoder that converts Swift values into TOON format.
///
/// This encoder conforms to the TOON (Token-Oriented Object Notation) specification version 4.1.
/// For more information, see https://github.com/toon-format/spec
public final class TOONEncoder {
    /// The number of spaces of one indentation level.
    ///
    /// TOON specification 13 names this option `indentSize`, with a default
    /// of 2. Section 13.1 is the conformance checklist of an encoder, and
    /// defines no option.
    public var indentSize: Int = 2

    /// The former name of ``indentSize``.
    ///
    /// The specification took the name `indentSize` in release 3.3. The
    /// compatibility note of release 4.1 lets an implementation keep the old
    /// name as a deprecated alias.
    @available(*, deprecated, renamed: "indentSize")
    public var indent: Int {
        get { indentSize }
        set { indentSize = newValue }
    }

    /// The delimiter character used to separate array values and tabular row cells.
    ///
    /// The delimiter determines how multiple values are separated in inline arrays
    /// and tabular data rows.
    ///
    /// Example with `.comma`:
    /// ```toon
    /// tags[3]: reading,gaming,coding
    /// ```
    ///
    /// Example with `.tab`:
    /// ```toon
    /// items[2	]{sku	name}:
    ///   A1	Widget
    ///   B2	Gadget
    /// ```
    ///
    /// Example with `.pipe`:
    /// ```toon
    /// items[2|]{sku|name}:
    ///   A1|Widget
    ///   B2|Gadget
    /// ```
    public enum Delimiter: String, CaseIterable, Hashable, Sendable {
        /// Comma separator (`,`).
        case comma = ","

        /// Tab separator (`\t`).
        case tab = "\t"

        /// Pipe separator (`|`).
        case pipe = "|"
    }

    /// The delimiter to use for array values and tabular rows.
    public var delimiter: Delimiter = .comma

    /// Strategy for encoding negative zero values.
    public enum NegativeZeroEncodingStrategy: Hashable, Sendable {
        /// Normalizes `-0.0` to `0`.
        case normalize

        /// Preserves `-0.0` as `-0`.
        case preserve
    }

    /// The strategy to use for encoding negative zero values.
    public var negativeZeroEncodingStrategy: NegativeZeroEncodingStrategy = .normalize

    /// Strategy for encoding non-conforming floating-point values.
    public enum NonConformingFloatEncodingStrategy: Hashable, Sendable {
        /// Encodes non-finite values as `null`.
        case null

        /// Throws an error on non-finite values.
        case `throw`

        /// Encodes non-finite values as string literals.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for encoding non-conforming floating-point values.
    public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .null

    /// Key folding mode.
    public enum KeyFolding: Hashable, Sendable {
        /// No key folding.
        case disabled

        /// Safe key folding.
        ///
        /// Only folds when all segments are valid identifiers.
        case safe
    }

    /// Key folding mode for collapsing single-key object chains into dotted paths.
    ///
    /// When enabled, single-key nested objects like `{ a: { b: { c: 1 } } }`
    /// are collapsed into `a.b.c: 1`. Only applies when all segments are valid identifiers.
    ///
    /// Example with `.safe`:
    /// ```toon
    /// user.profile.name: John
    /// user.profile.age: 30
    /// ```
    @available(
        *,
        deprecated,
        message: """
            TOON specification 4.0 removed key folding. The option still \
            works, and stays off by default, but its output does not conform \
            to specification 4.1. It is removed in 2.0.
            """
    )
    public var keyFolding: KeyFolding {
        get { storedKeyFolding }
        set { storedKeyFolding = newValue }
    }

    /// Backing storage, so that the library can read the option without
    /// raising its own deprecation warning.
    private var storedKeyFolding: KeyFolding = .disabled

    /// The maximum number of segments to include in a folded path when `keyFolding` is `.safe`.
    ///
    /// Controls how many nested single-key objects are collapsed into a dotted path.
    /// - Default is `Int.max` (unlimited folding depth).
    /// - Values less than 2 have no practical folding effect.
    ///
    /// Example with `flattenDepth = 2`:
    /// - Input: `{ a: { b: { c: { d: 1 } } } }`
    /// - Output: `a.b:` followed by nested `c:` and `d: 1`
    ///
    /// Example with `flattenDepth = Int.max` (default):
    /// - Input: `{ a: { b: { c: 1 } } }`
    /// - Output: `a.b.c: 1`
    @available(
        *,
        deprecated,
        message: """
            TOON specification 4.0 removed key folding, which is the only \
            thing this option affects. It is removed in 2.0.
            """
    )
    public var flattenDepth: Int {
        get { storedFlattenDepth }
        set { storedFlattenDepth = newValue }
    }

    /// Backing storage, so that the library can read the option without
    /// raising its own deprecation warning.
    private var storedFlattenDepth: Int = .max

    /// Limits for encoding to prevent resource exhaustion.
    public struct EncodingLimits: Hashable, Sendable {
        /// Maximum nesting depth.
        public var maxDepth: Int

        /// Default limits suitable for most use cases.
        ///
        /// - `maxDepth`: 32 (prevents stack overflow from deep nesting)
        public static let `default` = EncodingLimits(maxDepth: 32)

        /// Encoding limits that impose no restrictions.
        ///
        /// - Warning: This configuration is unsafe for untrusted input
        ///   and should only be used with trusted data.
        public static let unlimited = EncodingLimits(maxDepth: .max)

        public init(maxDepth: Int) {
            self.maxDepth = maxDepth
        }
    }

    /// Limits for encoding to prevent resource exhaustion.
    ///
    /// Use this to protect against accidental or malicious deep nesting
    /// when encoding untrusted data.
    public var limits: EncodingLimits = .default

    /// Creates a new TOON encoder with default configuration.
    ///
    /// Default settings:
    /// - `indentSize`: 2 spaces
    /// - `delimiter`: `.comma`
    /// - `negativeZeroEncodingStrategy`: `.normalize`
    /// - `nonConformingFloatEncodingStrategy`: `.null`
    /// - `keyFolding`: `.disabled`
    /// - `flattenDepth`: `Int.max`
    /// - `limits`: `.default`
    public init() {}

    /// Encodes the given value into TOON format.
    ///
    /// - Parameter value: An `Encodable` value to convert to TOON format.
    /// - Returns: UTF-8 encoded data containing the TOON representation.
    /// - Throws: An error if encoding fails.
    ///
    /// This method handles special Foundation types (`Date`, `URL`, `Data`) as well as
    /// standard Swift types and custom `Encodable` types. Arrays of objects with consistent
    /// keys are automatically formatted as tabular data.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try validateIndentSize()

        // Handle special types before they encode themselves
        let mirror = Mirror(reflecting: value)
        let v: Value

        if mirror.subjectType == Date.self, let date = value as? Date {
            v = .date(date)
        } else if mirror.subjectType == URL.self, let url = value as? URL {
            v = .url(url)
        } else if mirror.subjectType == Data.self, let data = value as? Data {
            v = .data(data)
        } else {
            var userInfo = [CodingUserInfoKey: Any]()
            userInfo[.toonEncodingMaxDepth] = limits.maxDepth
            let encoder = Encoder(userInfo: userInfo)
            try value.encode(to: encoder)
            v = encoder.encodedValue
        }

        if case .throw = nonConformingFloatEncodingStrategy {
            try validateNonConformingFloats(in: v, codingPath: [])
        }

        var output: [String] = []
        encodeValue(v, output: &output, depth: 0)

        // Data(_:) takes the UTF-8 view of a native String, which always
        // exists. The earlier data(using:) returned an optional, and the
        // fallback would have given an empty document for a whole encode.
        return Data(output.joined(separator: "\n").utf8)
    }

    // MARK: - Encoding Entry Point

    private func encodeValue(_ value: Value, output: inout [String], depth: Int) {
        switch value {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            // Special case for root-level primitives
            if depth == 0 {
                if let encoded = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: false) {
                    write(depth: depth, content: encoded, to: &output)
                }
            }

        case .array(let array):
            encodeArray(key: nil, array: array, output: &output, depth: depth)

        case .object(let values):
            // At the root the keyed header carries no key (specification 9.5).
            if depth == 0, let header = detectKeyedTabularHeader(values) {
                encodeKeyedTabular(
                    key: nil,
                    values: values,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                encodeObject(values, output: &output, depth: depth)
            }
        }
    }

    /// Rejects an indentation size that the encoder cannot use.
    ///
    /// A size below one gives no indentation. A nested value then lands at the
    /// depth of its parent, and the output no longer holds the structure. A
    /// negative size traps in `String(repeating:count:)`. The encoder reports
    /// the mistake instead.
    private func validateIndentSize() throws {
        guard indentSize < 1 else { return }
        throw EncodingError.invalidValue(
            indentSize,
            EncodingError.Context(
                codingPath: [],
                debugDescription: "The indentation size must be one or more, not \(indentSize)."
            )
        )
    }

    // MARK: - Object Encoding

    private func encodeObject(
        _ values: ObjectStorage,
        output: inout [String],
        depth: Int,
        allowFolding: Bool = true
    ) {
        let siblingKeys = values.keys
        for element in values {
            encodeKeyValuePair(
                key: element.key,
                value: element.value,
                output: &output,
                depth: depth,
                siblingKeys: siblingKeys,
                allowFolding: allowFolding
            )
        }
    }

    /// Attempts to fold a key path by following single-key object chains.
    ///
    /// Returns the folded path, final value, and whether the depth limit was reached,
    /// or `nil` if folding is not safe.
    ///
    /// - Parameters:
    ///   - key: The starting key of the chain.
    ///   - value: The value associated with the key.
    ///   - siblingKeys: Other keys at the same object depth (for collision avoidance).
    private func tryFoldKeyPath(
        key: String,
        value: Value,
        siblingKeys: [String] = []
    ) -> (path: String, value: Value, hitDepthLimit: Bool)? {
        guard storedKeyFolding == .safe else { return nil }

        // Values less than 2 have no practical folding effect
        guard storedFlattenDepth >= 2 else { return nil }

        var pathComponents: [String] = [key]
        var currentValue = value
        var hitDepthLimit = false

        // Follow the chain of single-key objects, respecting flattenDepth limit
        while case .object(let nestedValues) = currentValue,
            nestedValues.count == 1,
            let single = nestedValues.first
        {
            let singleKey = single.key
            // Stop if we've reached the flattenDepth limit
            guard pathComponents.count < storedFlattenDepth else {
                hitDepthLimit = true
                break
            }

            // Validate that the key is a safe identifier
            guard singleKey.isValidIdentifierSegment else {
                break
            }

            pathComponents.append(singleKey)
            currentValue = single.value
        }

        // Only fold if we found at least one nested level
        guard pathComponents.count > 1 else { return nil }

        // Validate all components are safe identifiers
        guard pathComponents.allSatisfy({ $0.isValidIdentifierSegment }) else {
            return nil
        }

        let foldedPath = pathComponents.joined(separator: ".")

        // Collision avoidance: a folded key must not equal an existing
        // sibling key. A folded path holds ASCII identifier segments only, so
        // the scalar-exact comparison of section 16 never differs from the
        // canonical one here.
        if siblingKeys.containsKey(foldedPath) {
            return nil
        }

        return (path: foldedPath, value: currentValue, hitDepthLimit: hitDepthLimit)
    }

    private func encodeKeyValuePair(
        key: String,
        value: Value,
        output: inout [String],
        depth: Int,
        siblingKeys: [String] = [],
        allowFolding: Bool = true
    ) {
        // Try key folding if enabled and allowed
        if allowFolding,
            case let (path, value, hitDepthLimit)? = tryFoldKeyPath(key: key, value: value, siblingKeys: siblingKeys)
        {
            let encodedKey = encodeKey(path)

            switch value {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encodedValue = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: true) {
                    write(depth: depth, content: "\(encodedKey): \(encodedValue)", to: &output)
                }

            case .array(let array):
                encodeArray(key: path, array: array, output: &output, depth: depth)

            case .object(let values):
                write(depth: depth, content: "\(encodedKey):", to: &output)
                if !values.isEmpty {
                    encodeObject(
                        values,
                        output: &output,
                        depth: depth + 1,
                        allowFolding: !hitDepthLimit
                    )
                }
            }
            return
        }

        // Regular encoding without folding
        let encodedKey = encodeKey(key)

        switch value {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            if let encodedValue = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: true) {
                write(depth: depth, content: "\(encodedKey): \(encodedValue)", to: &output)
            }

        case .array(let array):
            encodeArray(key: key, array: array, output: &output, depth: depth)

        case .object(let values):
            if values.isEmpty {
                write(depth: depth, content: "\(encodedKey):", to: &output)
            } else if let header = detectKeyedTabularHeader(values) {
                // Specification 9.5 makes the keyed tabular form mandatory in
                // object-field position wherever detection succeeds.
                encodeKeyedTabular(
                    key: key,
                    values: values,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                write(depth: depth, content: "\(encodedKey):", to: &output)
                encodeObject(values, output: &output, depth: depth + 1)
            }
        }
    }

    private func encodeObjectAsListItem(
        values: ObjectStorage,
        output: inout [String],
        depth: Int
    ) {
        guard let first = values.first else {
            write(depth: depth, content: "-", to: &output)
            return
        }

        // First key-value on the same line as "- "
        let firstKey = first.key
        let encodedKey = encodeKey(firstKey)
        let firstValue = first.value

        switch firstValue {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            if let encodedValue = encodePrimitive(
                firstValue,
                delimiter: delimiter.rawValue,
                inObject: true
            ) {
                write(
                    depth: depth,
                    content: "- \(encodedKey): \(encodedValue)",
                    to: &output
                )
            }

        case .array(let array):
            if array.allSatisfy({ $0.isPrimitive }) {
                let formatted = formatInlineArray(values: array, key: firstKey)
                write(depth: depth, content: "- \(formatted)", to: &output)
            } else if array.allSatisfy({ $0.isObject }) {
                if let header = detectTabularHeader(array) {
                    let headerStr = formatHeader(
                        length: array.count,
                        key: firstKey,
                        fields: header,
                        delimiter: delimiter.rawValue
                    )
                    write(
                        depth: depth,
                        content: "- \(headerStr)",
                        to: &output
                    )
                    writeTabularRows(rows: array, header: header, output: &output, depth: depth + 2)
                } else {
                    write(
                        depth: depth,
                        content: "- \(encodedKey)[\(array.count)]:",
                        to: &output
                    )
                    for item in array {
                        if let values = item.objectValue {
                            encodeObjectAsListItem(
                                values: values,
                                output: &output,
                                depth: depth + 2
                            )
                        }
                    }
                }
            } else {
                write(
                    depth: depth,
                    content: "- \(encodedKey)[\(array.count)]:",
                    to: &output
                )
                for item in array {
                    switch item {
                    case .null, .bool, .int, .double, .string, .date, .url, .data:
                        if let encoded = encodePrimitive(
                            item,
                            delimiter: delimiter.rawValue,
                            inObject: false
                        ) {
                            write(
                                depth: depth + 2,
                                content: "- \(encoded)",
                                to: &output
                            )
                        }
                    case .array(let innerArray):
                        encodeInnerArrayAsListItem(
                            innerArray,
                            output: &output,
                            depth: depth + 2
                        )
                    case .object(let innerValues):
                        encodeObjectAsListItem(
                            values: innerValues,
                            output: &output,
                            depth: depth + 2
                        )
                    }
                }
            }

        case .object(let nestedValues):
            if nestedValues.isEmpty {
                write(depth: depth, content: "- \(encodedKey):", to: &output)
            } else if let header = detectKeyedTabularHeader(nestedValues) {
                // Specification 10 lets a keyed header sit on the hyphen line.
                // Its entry rows go two levels below that line, which puts the
                // sibling fields one level above them.
                var headerStr = encodeKey(firstKey)
                let delimiterSuffix = delimiter.rawValue != "," ? delimiter.rawValue : ""
                headerStr += "[\(nestedValues.count):\(delimiterSuffix)]"
                headerStr += "{\(formatFieldList(header, delimiter: delimiter.rawValue))}:"
                write(depth: depth, content: "- \(headerStr)", to: &output)

                for entry in nestedValues {
                    let cells = collectRowLeaves(entry.value, fields: header)
                    let row = joinEncodedValues(cells, delimiter: delimiter.rawValue)
                    write(
                        depth: depth + 2,
                        content: "\(encodeKey(entry.key)): \(row)",
                        to: &output
                    )
                }
            } else {
                write(depth: depth, content: "- \(encodedKey):", to: &output)
                encodeObject(nestedValues, output: &output, depth: depth + 2)
            }
        }

        // Remaining keys on indented lines
        let siblingKeys = values.keys
        for element in values.dropFirst() {
            encodeKeyValuePair(
                key: element.key,
                value: element.value,
                output: &output,
                depth: depth + 1,
                siblingKeys: siblingKeys
            )
        }
    }

    // MARK: - Array Encoding

    private func encodeArray(key: String?, array: [Value], output: inout [String], depth: Int) {
        // Specification 9.1 gives an empty array the canonical form `key: []`
        // at a field and `[]` at the root.
        if array.isEmpty {
            let line = key.map { "\(encodeKey($0)): []" } ?? "[]"
            write(depth: depth, content: line, to: &output)
            return
        }

        // Primitive array
        if array.allSatisfy({ $0.isPrimitive }) {
            encodeInlinePrimitiveArray(key: key, values: array, output: &output, depth: depth)
            return
        }

        // Array of arrays (all primitives)
        if array.allSatisfy({ $0.isArray }) {
            let allPrimitiveArrays = array.allSatisfy { arrayValue in
                guard let innerArray = arrayValue.arrayValue else { return false }
                return innerArray.allSatisfy { $0.isPrimitive }
            }
            if allPrimitiveArrays {
                encodeArrayOfArraysAsListItems(
                    key: key,
                    values: array,
                    output: &output,
                    depth: depth
                )
                return
            }
        }

        // Array of objects
        if array.allSatisfy({ $0.isObject }) {
            if let header = detectTabularHeader(array) {
                encodeArrayOfObjectsAsTabular(
                    key: key,
                    rows: array,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                encodeMixedArrayAsListItems(key: key, items: array, output: &output, depth: depth)
            }
            return
        }

        // Mixed array: fallback to expanded format
        encodeMixedArrayAsListItems(key: key, items: array, output: &output, depth: depth)
    }

    private func encodeInlinePrimitiveArray(
        key: String?,
        values: [Value],
        output: inout [String],
        depth: Int
    ) {
        let formatted = formatInlineArray(values: values, key: key)
        write(depth: depth, content: formatted, to: &output)
    }

    private func encodeArrayOfArraysAsListItems(
        key: String?,
        values: [Value],
        output: inout [String],
        depth: Int
    ) {
        let header = formatHeader(
            length: values.count,
            key: key,
            delimiter: delimiter.rawValue
        )
        write(depth: depth, content: header, to: &output)

        for arrayValue in values {
            guard let innerArray = arrayValue.arrayValue else { continue }
            let inline = formatInlineArray(values: innerArray, key: nil, inListItem: true)
            write(depth: depth + 1, content: "- \(inline)", to: &output)
        }
    }

    private func encodeArrayOfObjectsAsTabular(
        key: String?,
        rows: [Value],
        header: [FieldNode],
        output: inout [String],
        depth: Int
    ) {
        let headerStr = formatHeader(
            length: rows.count,
            key: key,
            fields: header,
            delimiter: delimiter.rawValue
        )
        write(depth: depth, content: headerStr, to: &output)

        writeTabularRows(rows: rows, header: header, output: &output, depth: depth + 1)
    }

    /// Writes an inner array that sits on a hyphen line.
    ///
    /// Specification 6 allows a keyless header to carry a field list only at
    /// the document root. An inner array that the tabular form would fit
    /// therefore takes the list form here.
    private func encodeInnerArrayAsListItem(_ array: [Value], output: inout [String], depth: Int) {
        if array.allSatisfy({ $0.isPrimitive }) {
            let inline = formatInlineArray(values: array, key: nil, inListItem: true)
            write(depth: depth, content: "- \(inline)", to: &output)
            return
        }

        write(depth: depth, content: "- [\(array.count)]:", to: &output)
        for item in array {
            switch item {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encoded = encodePrimitive(
                    item,
                    delimiter: delimiter.rawValue,
                    inObject: false
                ) {
                    write(depth: depth + 1, content: "- \(encoded)", to: &output)
                }
            case .array(let inner):
                encodeInnerArrayAsListItem(inner, output: &output, depth: depth + 1)
            case .object(let values):
                encodeObjectAsListItem(
                    values: values,
                    output: &output,
                    depth: depth + 1
                )
            }
        }
    }

    private func encodeMixedArrayAsListItems(
        key: String?,
        items: [Value],
        output: inout [String],
        depth: Int
    ) {
        let header = formatHeader(
            length: items.count,
            key: key,
            delimiter: delimiter.rawValue
        )
        write(depth: depth, content: header, to: &output)

        for item in items {
            switch item {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encoded = encodePrimitive(item, delimiter: delimiter.rawValue, inObject: false) {
                    write(depth: depth + 1, content: "- \(encoded)", to: &output)
                }

            case .array(let array):
                encodeInnerArrayAsListItem(array, output: &output, depth: depth + 1)

            case .object(let values):
                encodeObjectAsListItem(
                    values: values,
                    output: &output,
                    depth: depth + 1
                )
            }
        }
    }

    // MARK: - Tabular Encoding

    /// The field list for an array of uniform objects, or `nil` when the
    /// array does not take the tabular form.
    ///
    /// TOON specification 9.3 requires every column - the values at one key
    /// across the rows - to be uniform-primitive or nested-uniform. A
    /// nested-uniform column collapses into a nested field group, and the
    /// rule applies again inside it, with no depth cap.
    ///
    /// An array that holds an empty object never takes the tabular form,
    /// because an empty object has no column to describe.
    private func detectTabularHeader(_ rows: [Value]) -> [FieldNode]? {
        guard let firstRow = rows.first?.objectValue, !firstRow.isEmpty else {
            return nil
        }

        // Every row is an object with the same set of keys. The order inside a
        // row may differ; the header order wins, per section 9.3.
        let headerKeys = firstRow.keys
        for row in rows {
            guard let values = row.objectValue, values.count == headerKeys.count else {
                return nil
            }
            for key in headerKeys where values[key] == nil {
                return nil
            }
        }

        var fields: [FieldNode] = []
        for key in headerKeys {
            let column = rows.compactMap { $0.objectValue?[key] }
            if column.allSatisfy({ $0.isPrimitive }) {
                fields.append(FieldNode(name: key))
            } else if let children = detectTabularHeader(column) {
                fields.append(FieldNode(name: key, children: children))
            } else {
                return nil
            }
        }

        return fields
    }

    /// The field list for an object that takes the keyed tabular form, or
    /// `nil` when it does not.
    ///
    /// TOON specification 9.5 requires at least two entries, and every entry
    /// value to be a non-empty object. The columns then follow the rules of
    /// section 9.3, so the detection reuses ``detectTabularHeader``.
    private func detectKeyedTabularHeader(_ values: ObjectStorage) -> [FieldNode]? {
        guard values.count >= 2 else { return nil }

        let entries = values.values
        guard entries.allSatisfy({ $0.isObject }) else {
            return nil
        }

        return detectTabularHeader(entries)
    }

    /// Writes a keyed tabular scope: the header, then one row per entry.
    private func encodeKeyedTabular(
        key: String?,
        values: ObjectStorage,
        header: [FieldNode],
        output: inout [String],
        depth: Int
    ) {
        var headerStr = ""
        if let key = key {
            headerStr += encodeKey(key)
        }
        let delimiterSuffix = delimiter.rawValue != "," ? delimiter.rawValue : ""
        headerStr += "[\(values.count):\(delimiterSuffix)]"
        headerStr += "{\(formatFieldList(header, delimiter: delimiter.rawValue))}:"
        write(depth: depth, content: headerStr, to: &output)

        for entry in values {
            let cells = collectRowLeaves(entry.value, fields: header)
            let row = joinEncodedValues(cells, delimiter: delimiter.rawValue)
            write(depth: depth + 1, content: "\(encodeKey(entry.key)): \(row)", to: &output)
        }
    }

    /// The cells of one row, in the depth-first order of the leaves.
    private func collectRowLeaves(_ row: Value, fields: [FieldNode]) -> [Value] {
        guard let values = row.objectValue else { return [] }

        var cells: [Value] = []
        for field in fields {
            guard let value = values[field.name] else { continue }
            if let children = field.children {
                cells.append(contentsOf: collectRowLeaves(value, fields: children))
            } else {
                cells.append(value)
            }
        }
        return cells
    }

    private func writeTabularRows(
        rows: [Value],
        header: [FieldNode],
        output: inout [String],
        depth: Int
    ) {
        for row in rows {
            let cells = collectRowLeaves(row, fields: header)
            let joinedValue = joinEncodedValues(cells, delimiter: delimiter.rawValue)
            write(depth: depth, content: joinedValue, to: &output)
        }
    }

    // MARK: - Primitive Encoding

    private func encodePrimitive(_ value: Value, delimiter: String = ",", inObject: Bool = false)
        -> String?
    {
        switch value {
        case .null:
            return "null"
        case .bool(let boolValue):
            return String(boolValue)
        case .int(let intValue):
            return String(intValue)
        case .double(let doubleValue):
            // Check for non-finite numbers first
            if !doubleValue.isFinite {
                switch nonConformingFloatEncodingStrategy {
                case .null:
                    return "null"
                case .throw:
                    preconditionFailure(
                        "Encountered non-finite Double while nonConformingFloatEncodingStrategy is .throw. "
                            + "This path should be unreachable because validation occurs earlier."
                    )
                case .convertToString(let positiveInfinity, let negativeInfinity, let nan):
                    let literal: String
                    if doubleValue.isNaN {
                        literal = nan
                    } else if doubleValue.sign == .minus {
                        literal = negativeInfinity
                    } else {
                        literal = positiveInfinity
                    }
                    return encodeStringLiteral(literal, delimiter: delimiter)
                }
            }

            // Format numbers in decimal form without scientific notation
            if doubleValue == 0.0 && doubleValue.sign == .minus {
                switch negativeZeroEncodingStrategy {
                case .normalize:
                    return "0"
                case .preserve:
                    return "-0"
                }
            }

            return canonicalDecimal(doubleValue)
        case .string(let stringValue):
            return encodeStringLiteral(stringValue, delimiter: delimiter)
        case .date(let date):
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = iso8601.string(from: date)
            return encodeStringLiteral(dateString, delimiter: delimiter)
        case .url(let url):
            return encodeStringLiteral(url.absoluteString, delimiter: delimiter)
        case .data(let data):
            let base64 = data.base64EncodedString()
            return encodeStringLiteral(base64, delimiter: delimiter)
        case .array, .object:
            return nil
        }
    }

    private func validateNonConformingFloats(
        in value: Value,
        codingPath: [CodingKey]
    ) throws {
        struct ValidationCodingKey: CodingKey {
            let stringValue: String
            let intValue: Int?

            init(stringValue: String) {
                self.stringValue = stringValue
                self.intValue = nil
            }

            init(intValue: Int) {
                self.stringValue = String(intValue)
                self.intValue = intValue
            }
        }

        switch value {
        case .double(let doubleValue):
            guard doubleValue.isFinite else {
                throw EncodingError.invalidValue(
                    doubleValue,
                    EncodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Non-conforming float value: \(doubleValue)"
                    )
                )
            }
        case .array(let array):
            for (index, item) in array.enumerated() {
                var nextPath = codingPath
                nextPath.append(ValidationCodingKey(intValue: index))
                try validateNonConformingFloats(in: item, codingPath: nextPath)
            }
        case .object(let values):
            for element in values {
                var nextPath = codingPath
                nextPath.append(ValidationCodingKey(stringValue: element.key))
                try validateNonConformingFloats(in: element.value, codingPath: nextPath)
            }
        case .null, .bool, .int, .string, .date, .url, .data:
            break
        }
    }

    private func encodeStringLiteral(_ value: String, delimiter: String = ",")
        -> String
    {
        if value.isSafeUnquoted(delimiter: delimiter) {
            return value
        }

        return "\"\(value.escaped)\""
    }

    private func encodeKey(_ key: String) -> String {
        if key.isValidUnquotedKey {
            return key
        }

        return "\"\(key.escaped)\""
    }

    // MARK: - Formatting Helpers

    /// Renders an inline array.
    ///
    /// - Parameter inListItem: `true` when the array is an inner array on a
    ///   hyphen line. Specification 9.2 keeps the `[0]:` form there, while
    ///   section 9.1 gives every other position the canonical empty form.
    private func formatInlineArray(
        values: [Value],
        key: String?,
        inListItem: Bool = false
    ) -> String {
        // Specification 9.1 gives an empty array the canonical form `key: []`
        // at a field and `[]` at the root. The old `key[0]:` form is still
        // accepted on decode, but an encoder must not emit it.
        if values.isEmpty, !inListItem {
            guard let key = key else { return "[]" }
            return "\(encodeKey(key)): []"
        }

        let header = formatHeader(
            length: values.count,
            key: key,
            delimiter: delimiter.rawValue
        )

        if values.isEmpty {
            return header
        }

        let joinedValue = joinEncodedValues(values, delimiter: delimiter.rawValue)
        return "\(header) \(joinedValue)"
    }

    /// Renders a field list, and recurses into a nested field group.
    ///
    /// A name follows the key encoding of specification 7.3 at every level.
    private func formatFieldList(_ fields: [FieldNode], delimiter: String) -> String {
        fields.map { field in
            guard let children = field.children else { return encodeKey(field.name) }
            let inner = formatFieldList(children, delimiter: delimiter)
            return "\(encodeKey(field.name)){\(inner)}"
        }
        .joined(separator: delimiter)
    }

    private func formatHeader(
        length: Int,
        key: String? = nil,
        fields: [FieldNode]? = nil,
        delimiter: String = ","
    ) -> String {
        var header = ""

        if let key = key {
            header += encodeKey(key)
        }

        // Only include delimiter if it's not the default (comma)
        let delimiterSuffix = delimiter != "," ? delimiter : ""
        header += "[\(length)\(delimiterSuffix)]"

        if let fields = fields {
            header += "{\(formatFieldList(fields, delimiter: delimiter))}"
        }

        header += ":"

        return header
    }

    private func joinEncodedValues(_ values: [Value], delimiter: String = ",")
        -> String
    {
        return values.compactMap { encodePrimitive($0, delimiter: delimiter) }.joined(separator: delimiter)
    }

    private func write(depth: Int, content: String, to output: inout [String]) {
        let indentation = String(repeating: String(repeating: " ", count: indentSize), count: depth)
        output.append(indentation + content)
    }
}

fileprivate extension CodingUserInfoKey {
    static let toonEncodingMaxDepth = CodingUserInfoKey(rawValue: "toonEncodingMaxDepth")!
}

// MARK: - Internal Encoder

extension TOONEncoder {
    /// Internal encoder implementation that conforms to the `Encoder` protocol.
    private final class Encoder: Swift.Encoder {
        let codingPath: [any Swift.CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        fileprivate var storage: [Value]

        init(codingPath: [any Swift.CodingKey] = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.storage = []
        }

        func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
        where Key: Swift.CodingKey {
            let container = KeyedContainer<Key>(encoder: self, codingPath: codingPath)
            return KeyedEncodingContainer(container)
        }

        func unkeyedContainer() -> UnkeyedEncodingContainer {
            return UnkeyedContainer(encoder: self, codingPath: codingPath)
        }

        func singleValueContainer() -> SingleValueEncodingContainer {
            return SingleValueContainer(encoder: self, codingPath: codingPath)
        }

        var canEncodeNewValue: Bool {
            return storage.count == 0
        }

        func encode<T: Encodable>(_ value: T) throws {
            try value.encode(to: self)
        }

        var encodedValue: Value {
            if storage.count == 0 {
                // If no values in storage, return null as a fallback
                return .null
            }
            return storage.removeLast()
        }
    }
}

// MARK: - Keyed Encoding Container

extension TOONEncoder {
    private final class KeyedContainer<Key: Swift.CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        private var container: ObjectStorage = [:]

        /// Heuristic: Swift's `Dictionary` encoding uses an internal
        /// `DictionaryCodingKey` type.
        ///
        /// We detect this by checking whether `String(reflecting: Key.self)`
        /// is in the `Swift` module and contains the substring `"DictionaryCodingKey"`.
        /// If so, we treat the container as a dictionary and sort its keys lexicographically.
        ///
        /// This relies on Swift's internal implementation details
        /// and is therefore inherently fragile.
        /// If the type name changes in a future Swift version,
        /// this detection will stop working and dictionary key ordering may become
        /// non-deterministic again without a compile-time error.
        private let isDictionaryCodingKey: Bool = {
            let reflected = String(reflecting: Key.self)
            return reflected.hasPrefix("Swift.") && reflected.contains("DictionaryCodingKey")
        }()
        private var didFinishEncoding = false

        init(encoder: Encoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        func encodeNil(forKey key: Key) throws {
            container[key.stringValue] = .null
        }

        func encode(_ value: Bool, forKey key: Key) throws {
            container[key.stringValue] = .bool(value)
        }

        func encode(_ value: String, forKey key: Key) throws {
            container[key.stringValue] = .string(value)
        }

        func encode(_ value: Double, forKey key: Key) throws {
            container[key.stringValue] = .double(value)
        }

        func encode(_ value: Float, forKey key: Key) throws {
            container[key.stringValue] = .double(Double(value))
        }

        func encode(_ value: Int, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int8, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int16, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int32, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int64, forKey key: Key) throws {
            container[key.stringValue] = .int(value)
        }

        func encode(_ value: UInt, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt8, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt16, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt32, forKey key: Key) throws {
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt64, forKey key: Key) throws {
            if value <= Int64.max {
                container[key.stringValue] = .int(Int64(value))
            } else {
                container[key.stringValue] = .string(String(value))
            }
        }

        func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            if let limit = encoder.userInfo[.toonEncodingMaxDepth] as? Int, encoder.codingPath.count > limit {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath + [key],
                        debugDescription: "Recursion limit of \(limit) exceeded"
                    )
                )
            }

            // Handle special types by checking the mirror of the value
            // We need to use the Mirror because Date, URL, and Data conform to Codable
            // and would otherwise encode themselves using their default implementations

            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                container[key.stringValue] = .date(date)
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                container[key.stringValue] = .url(url)
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                container[key.stringValue] = .data(data)
                return
            }

            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            try value.encode(to: nestedEncoder)
            container[key.stringValue] = nestedEncoder.encodedValue
        }

        func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: String?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
            -> KeyedEncodingContainer<NestedKey> where NestedKey: Swift.CodingKey
        {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            let container = KeyedContainer<NestedKey>(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            return UnkeyedContainer(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
        }

        func superEncoder() -> Swift.Encoder {
            return encoder
        }

        func superEncoder(forKey key: Key) -> Swift.Encoder {
            return encoder
        }

        func finishEncoding() {
            guard !didFinishEncoding else { return }
            didFinishEncoding = true
            encoder.storage.append(.object(isDictionaryCodingKey ? container.sortedByKey() : container))
        }

        deinit {
            // Ensure the container is finished when it goes out of scope
            finishEncoding()
        }
    }
}

// MARK: - Unkeyed Encoding Container

extension TOONEncoder {
    private final class UnkeyedContainer: UnkeyedEncodingContainer {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        private var container: [Value] = []

        init(encoder: Encoder, codingPath: [any Swift.CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        var count: Int {
            return container.count
        }

        func encodeNil() throws {
            container.append(.null)
        }

        func encode(_ value: Bool) throws {
            container.append(.bool(value))
        }

        func encode(_ value: String) throws {
            container.append(.string(value))
        }

        func encode(_ value: Double) throws {
            container.append(.double(value))
        }

        func encode(_ value: Float) throws {
            container.append(.double(Double(value)))
        }

        func encode(_ value: Int) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int8) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int16) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int32) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int64) throws {
            container.append(.int(value))
        }

        func encode(_ value: UInt) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt8) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt16) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt32) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt64) throws {
            if value <= Int64.max {
                container.append(.int(Int64(value)))
            } else {
                container.append(.string(String(value)))
            }
        }

        func encode<T: Encodable>(_ value: T) throws {
            if let limit = encoder.userInfo[.toonEncodingMaxDepth] as? Int, encoder.codingPath.count > limit {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                        debugDescription: "Recursion limit of \(limit) exceeded"
                    )
                )
            }
            // Handle special types
            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                container.append(.date(date))
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                container.append(.url(url))
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                container.append(.data(data))
                return
            }

            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            try value.encode(to: nestedEncoder)
            container.append(nestedEncoder.encodedValue)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<
            NestedKey
        > where NestedKey: Swift.CodingKey {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            let container = KeyedContainer<NestedKey>(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            return UnkeyedContainer(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
        }

        func superEncoder() -> Swift.Encoder {
            return encoder
        }

        func finishEncoding() {
            encoder.storage.append(.array(container))
        }

        deinit {
            // Ensure the container is finished when it goes out of scope
            encoder.storage.append(.array(container))
        }
    }
}

// MARK: - Single Value Encoding Container

extension TOONEncoder {
    private final class SingleValueContainer: SingleValueEncodingContainer {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        init(encoder: Encoder, codingPath: [any Swift.CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        func encodeNil() throws {
            encoder.storage.append(.null)
        }

        func encode(_ value: Bool) throws {
            encoder.storage.append(.bool(value))
        }

        func encode(_ value: String) throws {
            encoder.storage.append(.string(value))
        }

        func encode(_ value: Double) throws {
            encoder.storage.append(.double(value))
        }

        func encode(_ value: Float) throws {
            encoder.storage.append(.double(Double(value)))
        }

        func encode(_ value: Int) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int8) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int16) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int32) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int64) throws {
            encoder.storage.append(.int(value))
        }

        func encode(_ value: UInt) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt8) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt16) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt32) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt64) throws {
            if value <= Int64.max {
                encoder.storage.append(.int(Int64(value)))
            } else {
                encoder.storage.append(.string(String(value)))
            }
        }

        func encode<T: Encodable>(_ value: T) throws {
            if let limit = encoder.userInfo[.toonEncodingMaxDepth] as? Int, encoder.codingPath.count > limit {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Recursion limit of \(limit) exceeded"
                    )
                )
            }
            // Handle special types
            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                encoder.storage.append(.date(date))
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                encoder.storage.append(.url(url))
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                encoder.storage.append(.data(data))
                return
            }

            let nestedEncoder = Encoder(codingPath: codingPath, userInfo: encoder.userInfo)
            try value.encode(to: nestedEncoder)
            encoder.storage.append(nestedEncoder.encodedValue)
        }

        deinit {
            // Single value containers don't need finishEncoding, they push values directly
        }
    }
}

// MARK: - Number Formatting

/// Renders a finite `Double` in the canonical decimal form of TOON
/// specification 2.
///
/// The description of a `Double` in Swift is the shortest text that reads back
/// as the same value. Section 2 asks for exactly that: an encoder must emit
/// enough precision that decoding its output returns the input. The earlier
/// code used a NumberFormatter capped at 15 fraction digits. That cap rounded
/// 0.3333333333333333 to fifteen threes, and turned 1e-16 into 0.
///
/// Swift writes a whole value as "1.0" and uses an exponent outside a range of
/// its own, so the two cases are adjusted here. Section 2 asks for a plain
/// decimal inside one band of magnitudes. The band holds zero, and every
/// magnitude from 1e-6 up to 1e21. Outside it, the exponent form is allowed.
private func canonicalDecimal(_ value: Double) -> String {
    let magnitude = abs(value)
    let usesPlainForm = magnitude == 0 || (magnitude >= 1e-6 && magnitude < 1e21)

    guard usesPlainForm else {
        // Outside the band, section 2 allows the exponent form. The description
        // of a Double is already the shortest text that reads back as the same
        // value.
        return String(value)
    }

    // The shortest fixed-point text that reads back as the same value. Trying
    // the digits in order means the result never carries a trailing zero.
    for digits in 0 ... 25 {
        let text = String(format: "%.\(digits)f", value)
        if Double(text) == value {
            return text
        }
    }

    return String(value)
}

// MARK: - String Extensions

private extension String {
    /// Escapes a string for a quoted span, per TOON specification 7.1.
    ///
    /// The table has five short forms. Every other character in U+0000 through
    /// U+001F takes the `\uXXXX` form, which the specification requires.
    var escaped: String {
        var result = String.UnicodeScalarView()
        for scalar in unicodeScalars {
            switch scalar {
            case "\\": result.append(contentsOf: "\\\\".unicodeScalars)
            case "\"": result.append(contentsOf: "\\\"".unicodeScalars)
            case "\n": result.append(contentsOf: "\\n".unicodeScalars)
            case "\r": result.append(contentsOf: "\\r".unicodeScalars)
            case "\t": result.append(contentsOf: "\\t".unicodeScalars)
            default:
                if scalar.value <= 0x1F {
                    let hex = String(format: "%04x", scalar.value)
                    result.append(contentsOf: "\\u\(hex)".unicodeScalars)
                } else {
                    result.append(scalar)
                }
            }
        }
        return String(result)
    }

    /// Whether the string matches `^[+-]?[0-9]+(\.[0-9]+)?(e[+-]?[0-9]+)?$`
    /// with ASCII digits, per specification 7.2.
    ///
    /// This is wider than the decoder grammar of section 4: it also covers
    /// `+1` and `05`, which decode as strings. An encoder quotes them so that
    /// the value cannot read as a number.
    var isNumericLike: Bool {
        let scalars = Array(unicodeScalars)
        var index = 0

        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
            index += 1
        }

        let integerStart = index
        while index < scalars.count, scalars[index].isASCIIDigit {
            index += 1
        }
        guard index > integerStart else { return false }

        if index < scalars.count, scalars[index] == "." {
            index += 1
            let fractionStart = index
            while index < scalars.count, scalars[index].isASCIIDigit {
                index += 1
            }
            guard index > fractionStart else { return false }
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
            guard index > exponentStart else { return false }
        }

        return index == scalars.count
    }

    /// Whether the string starts or ends with U+0020 or U+0009.
    ///
    /// Specification 7.2 names exactly those two. CharacterSet.whitespaces
    /// also holds every Unicode space separator, and section 12 states that
    /// such a character is part of the token.
    var isPaddedWithWhitespace: Bool {
        guard let first = unicodeScalars.first, let last = unicodeScalars.last else {
            return false
        }
        let isPad = { (scalar: Unicode.Scalar) in scalar == " " || scalar == "\t" }
        return isPad(first) || isPad(last)
    }

    /// Whether the string may appear without quotes, per specification 7.2.
    func isSafeUnquoted(delimiter: String = ",") -> Bool {
        if isEmpty {
            return false
        }

        if isPaddedWithWhitespace {
            return false
        }

        if self == "true" || self == "false" || self == "null" {
            return false
        }

        if isNumericLike {
            return false
        }

        for scalar in unicodeScalars {
            switch scalar {
            case ":", "\"", "\\", "[", "]", "{", "}":
                return false
            default:
                if scalar.value <= 0x1F {
                    return false
                }
            }
        }

        if contains(delimiter) {
            return false
        }

        // A hyphen at position 0 reads as the list marker, and a number sign
        // at position 0 reads as a comment line (section 5.1).
        if hasPrefix("-") || hasPrefix("#") {
            return false
        }

        // Stricter than the specification, which obliges only a decoder to
        // strip a leading byte-order mark (section 12). Without this, a root
        // string that starts with U+FEFF loses its first character on a round
        // trip. Reported upstream as toon-format/toon issue 339.
        if unicodeScalars.first == "\u{FEFF}" {
            return false
        }

        return true
    }

    /// Whether the key may appear without quotes.
    ///
    /// Specification 7.3 gives the pattern `^[A-Za-z_][A-Za-z0-9_.]*$`. The
    /// `\w` class of NSRegularExpression covers every Unicode letter, so the
    /// old pattern left a key such as `naive` with a diaeresis unquoted,
    /// against section 16.
    var isValidUnquotedKey: Bool {
        var scalars = Array(unicodeScalars).makeIterator()
        guard let first = scalars.next(), first.isASCIILetter || first == "_" else {
            return false
        }
        while let scalar = scalars.next() {
            guard scalar.isASCIILetter || scalar.isASCIIDigit || scalar == "_" || scalar == "."
            else {
                return false
            }
        }
        return true
    }

    /// A single segment of a folded key path: the pattern of specification
    /// 7.3 without the dot.
    var isValidIdentifierSegment: Bool {
        !isEmpty && !contains(".") && isValidUnquotedKey
    }
}

extension Unicode.Scalar {
    /// `true` for an ASCII letter only.
    fileprivate var isASCIILetter: Bool {
        (self >= "A" && self <= "Z") || (self >= "a" && self <= "z")
    }
}
