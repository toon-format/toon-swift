import Foundation

/// An intermediate representation for TOON values during encoding and decoding.
enum Value: Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case date(Date)
    case url(URL)
    case data(Data)
    case array([Value])
    case object([String: Value], keyOrder: [String])

    // MARK: - Type Checks

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var isPrimitive: Bool {
        switch self {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            return true
        case .array, .object:
            return false
        }
    }

    var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    // MARK: - Value Accessors

    var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    var intValue: Int64? {
        if case let .int(v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case let .double(v) = self { return v }
        // Also allow int to double conversion
        if case let .int(v) = self { return Double(v) }
        return nil
    }

    var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }

    var arrayValue: [Value]? {
        if case let .array(v) = self { return v }
        return nil
    }

    var objectValue: (values: [String: Value], keyOrder: [String])? {
        if case let .object(values, keyOrder) = self { return (values, keyOrder) }
        return nil
    }

    var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .string: return "string"
        case .date: return "date"
        case .url: return "url"
        case .data: return "data"
        case .array: return "array"
        case .object: return "object"
        }
    }

    // MARK: - Array Type Checks

    var isArrayOfPrimitives: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isPrimitive }
    }

    var isArrayOfArrays: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isArray }
    }

    var isArrayOfObjects: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isObject }
    }
}

// MARK: - Coding Key

struct IndexedCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
