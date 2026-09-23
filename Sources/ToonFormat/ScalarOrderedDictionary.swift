/// A dictionary key that compares and hashes by Unicode scalar sequence.
struct ScalarKey: Hashable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    static func == (lhs: ScalarKey, rhs: ScalarKey) -> Bool {
        lhs.value.unicodeScalars.elementsEqual(rhs.value.unicodeScalars)
    }

    func hash(into hasher: inout Hasher) {
        for scalar in value.unicodeScalars {
            hasher.combine(scalar)
        }
    }
}

/// An ordered map with the key identity that TOON specification section 2 and
/// section 16 require. Two keys are the same key only when their Unicode scalar
/// sequences are equal.
///
/// The Swift `String` type compares by canonical equivalence, so a plain
/// `[String: Value]` merges two keys that differ only in normalization form.
/// The type also keeps the insertion order, because section 2 requires an
/// encoder to preserve the order of the keys.
struct ScalarOrderedDictionary<Value> {
    /// One key-value pair.
    struct Element {
        let key: String
        var value: Value
    }

    private var elements: [Element]
    private var index: [ScalarKey: Int]

    init() {
        elements = []
        index = [:]
    }

    /// The keys, in insertion order.
    var keys: [String] { elements.map(\.key) }

    /// The values, in insertion order.
    var values: [Value] { elements.map(\.value) }

    /// Reads or writes the value of the key.
    ///
    /// A write to a key that the map already holds keeps the position of that
    /// key. A write of `nil` removes the key.
    subscript(key: String) -> Value? {
        get {
            guard let position = index[ScalarKey(key)] else { return nil }
            return elements[position].value
        }
        set {
            let scalarKey = ScalarKey(key)
            switch (index[scalarKey], newValue) {
            case let (position?, value?):
                elements[position].value = value
            case let (nil, value?):
                index[scalarKey] = elements.count
                elements.append(Element(key: key, value: value))
            case let (position?, nil):
                elements.remove(at: position)
                index.removeValue(forKey: scalarKey)
                for offset in position ..< elements.count {
                    index[ScalarKey(elements[offset].key)] = offset
                }
            case (nil, nil):
                break
            }
        }
    }

    /// The map with its keys in ascending order.
    func sortedByKey() -> Self {
        var result = Self()
        for key in keys.sorted() {
            result[key] = self[key]
        }
        return result
    }
}

extension ScalarOrderedDictionary: RandomAccessCollection {
    var startIndex: Int { elements.startIndex }
    var endIndex: Int { elements.endIndex }
    subscript(position: Int) -> Element { elements[position] }
}

extension ScalarOrderedDictionary: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral pairs: (String, Value)...) {
        self.init()
        for (key, value) in pairs {
            self[key] = value
        }
    }
}

// Scalar-exact equality, per section 2 and section 16. A synthesized
// conformance would compare the keys by canonical equivalence.
extension ScalarOrderedDictionary: Equatable where Value: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.elements.count == rhs.elements.count else { return false }
        return zip(lhs.elements, rhs.elements).allSatisfy { left, right in
            left.key.unicodeScalars.elementsEqual(right.key.unicodeScalars)
                && left.value == right.value
        }
    }
}

extension ScalarOrderedDictionary: Hashable where Value: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(elements.count)
        for element in elements {
            for scalar in element.key.unicodeScalars {
                hasher.combine(scalar)
            }
            hasher.combine(element.value)
        }
    }
}

extension ScalarOrderedDictionary: Sendable where Value: Sendable {}
extension ScalarOrderedDictionary.Element: Sendable where Value: Sendable {}

extension [String] {
    /// Whether the array holds the key, compared by Unicode scalar sequence.
    func containsKey(_ key: String) -> Bool {
        contains { $0.unicodeScalars.elementsEqual(key.unicodeScalars) }
    }
}
