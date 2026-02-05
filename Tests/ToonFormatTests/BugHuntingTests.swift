import XCTest
@testable import ToonFormat

// MARK: - Helpers

extension Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .date(let v): try container.encode(v)
        case .url(let v): try container.encode(v)
        case .data(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v, _): try container.encode(v) // Ignore keyOrder for re-encoding
        }
    }
}

final class BugHuntingTests: XCTestCase {

    // MARK: - 1. Dictionary Non-Determinism in Value.from
    
    func testValueFromDictionaryKeyOrder() {
        // Create a dictionary with enough keys to have a high probability of random ordering
        let dict: [String: Any] = [
            "z": 1, "a": 2, "m": 3, "c": 4, "k": 5, "b": 6, "y": 7
        ]
        
        // This relies on Value.from which takes [String: Any]
        let value = Value.from(dict)
        
        guard case .object(_, let keyOrder) = value else {
            XCTFail("Value.from(dict) should return .object")
            return
        }
        
        let sortedKeys = keyOrder.sorted()
        
        // Assert that keys are sorted. If checks fail, it confirms non-deterministic behavior.
        XCTAssertEqual(keyOrder, sortedKeys, "Value.from produced unsorted keys")
    }
    
    // MARK: - 2. Double Negative Zero
    
    func testNegativeZeroEncoding() throws {
        let negativeZero: Double = -0.0
        let encoder = TOONEncoder()
        
        // Encode directly
        let data = try encoder.encode(["value": negativeZero])
        let string = String(data: data, encoding: .utf8)!
        
        print("Encoded Negative Zero: \(string)")
        
        // Expect strict -0 preservation or at least consistent float representation
        XCTAssertTrue(string.contains("-0"), "Negative zero sign lost: \(string)")
    }

    // MARK: - 3. Recursion Limit (Stack Overflow)
    
    func testDeepRecursion() {
        // Create deeply nested structure
        var deepValue: Value = .int(1)
        // 1500 is enough to trigger the 1000 limit
        for _ in 0..<1500 {
            deepValue = .array([deepValue])
        }
        
        let encoder = TOONEncoder()
        // Default limit is 1000
        
        do {
            _ = try encoder.encode(["value": deepValue])
            XCTFail("Should have thrown recursion error")
        } catch EncodingError.invalidValue(_, let context) {
            XCTAssertTrue(context.debugDescription.contains("Recursion limit"), "Unexpected error message: \(context.debugDescription)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
