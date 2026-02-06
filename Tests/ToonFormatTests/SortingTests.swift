import Testing
@testable import ToonFormat

@Test func testDictionaryKeySorting() {
    let dict: [String: Int] = [
        "z": 1, "a": 2, "m": 3, "c": 4, "k": 5, "b": 6, "y": 7,
    ]

    // Convert to [String: Any] for Value.from
    let anyDict: [String: Any] = dict

    let value = Value.from(anyDict)

    if case .object(_, let keyOrder) = value {
        let sortedKeys = keyOrder.sorted()
        #expect(keyOrder == sortedKeys, "Value.from produced unsorted keys. Expected \(sortedKeys), got \(keyOrder)")
    } else {
        #expect(Bool(false), "Value.from(dict) should return .object")
    }
}
