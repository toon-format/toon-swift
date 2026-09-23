import Foundation
import Testing

@testable import ToonFormat

/// Tests the JSON reader that feeds the conformance suite.
///
/// ``OrderedJSON`` reads the input and the expected value of every one of the
/// 538 fixture cases, so it decides whether a case passes. A reader that
/// accepts what JSON forbids, or that loses the order of the keys, makes a
/// case pass for the wrong reason. Nothing else in the suite can see that,
/// which is why the reader carries its own tests.
@Suite("Ordered JSON reader")
struct OrderedJSONTests {

    // MARK: - Key Order

    @Test("the reader keeps the order of the keys")
    func keepsKeyOrder() throws {
        let value = try OrderedJSON.parse(#"{"z": 1, "a": 2, "m": 3}"#)

        guard case let .object(object) = value else {
            Issue.record("Expected an object, got \(value)")
            return
        }
        #expect(object.keys == ["z", "a", "m"])
    }

    @Test("a repeated key keeps the position of its first appearance")
    func repeatedKeyKeepsTheFirstPosition() throws {
        let value = try OrderedJSON.parse(#"{"a": 1, "b": 2, "a": 3}"#)

        guard case let .object(object) = value else {
            Issue.record("Expected an object, got \(value)")
            return
        }
        #expect(object.keys == ["a", "b"])
        #expect(object["a"] == .int(3))
    }

    // MARK: - Numbers

    @Test(
        "the reader takes a number that JSON allows",
        arguments: [
            ("0", TOONValue.int(0)),
            ("-0", TOONValue.int(0)),
            ("12", TOONValue.int(12)),
            ("-12", TOONValue.int(-12)),
            ("0.5", TOONValue.double(0.5)),
            ("-0.5", TOONValue.double(-0.5)),
            ("1e3", TOONValue.double(1000)),
            ("1E+3", TOONValue.double(1000)),
            ("1e-3", TOONValue.double(0.001)),
            ("0e0", TOONValue.double(0)),
            ("9223372036854775807", TOONValue.int(.max)),
        ]
    )
    func takesAValidNumber(_ testCase: (String, TOONValue)) throws {
        #expect(try OrderedJSON.parse(testCase.0) == testCase.1)
    }

    /// Swift `Int64(_:)` and `Double(_:)` both have a wider grammar than JSON.
    /// A reader that scans loosely and then converts accepts every token
    /// below, which is how the earlier reader behaved.
    @Test(
        "the reader rejects a number that JSON forbids",
        arguments: ["007", "+5", ".5", "1.", "-", "--1", "1e", "1e+", "1.2.3", "0x10", "1_000"]
    )
    func rejectsAnInvalidNumber(_ token: String) {
        #expect(throws: OrderedJSON.ParseError.self) {
            try OrderedJSON.parse(token)
        }
    }

    @Test("a number that a Double cannot hold is an error")
    func rejectsANumberThatDoesNotFit() {
        #expect(throws: OrderedJSON.ParseError.self) {
            try OrderedJSON.parse("1e999")
        }
    }

    // MARK: - Strings

    @Test("the reader reads every escape that JSON defines")
    func readsEveryEscape() throws {
        let value = try OrderedJSON.parse(#"["\"\\\/\b\f\n\r\t\u0041"]"#)

        let expected = "\"" + "\\" + "/" + "\u{08}" + "\u{0C}" + "\n" + "\r" + "\t" + "A"
        #expect(value == .array([.string(expected)]))
    }

    @Test("the reader joins a surrogate pair")
    func joinsASurrogatePair() throws {
        #expect(try OrderedJSON.parse(#"["\ud83d\ude00"]"#) == .array([.string("😀")]))
    }

    @Test(
        "the reader rejects a broken escape",
        arguments: [#"["\ud800"]"#, #"["\udc00"]"#, #"["\u00"]"#, #"["\q"]"#, #"["a"#]
    )
    func rejectsABrokenEscape(_ text: String) {
        #expect(throws: OrderedJSON.ParseError.self) {
            try OrderedJSON.parse(text)
        }
    }

    /// JSON needs an escape for a scalar below U+0020. A raw one marks a
    /// damaged file, and a silent read would hide it.
    @Test("the reader rejects a raw control scalar")
    func rejectsARawControlScalar() {
        for scalar in ["\u{01}", "\n", "\t"] {
            #expect(throws: OrderedJSON.ParseError.self) {
                try OrderedJSON.parse("[\"a\(scalar)b\"]")
            }
        }
    }

    // MARK: - Structure

    @Test(
        "the reader rejects damaged structure",
        arguments: [#"{"a" 1}"#, "[1,]", "[,1]", "{,}", "[1] 2", #"{"a":}"#, "", "[1,2"]
    )
    func rejectsDamagedStructure(_ text: String) {
        #expect(throws: OrderedJSON.ParseError.self) {
            try OrderedJSON.parse(text)
        }
    }

    /// The reader calls itself for a nested value, so a file of many open
    /// brackets would overflow the stack and stop the test process.
    @Test("deep nesting is an error, not a crash")
    func deepNestingIsAnError() {
        let text = String(repeating: "[", count: 5000)
        #expect(throws: OrderedJSON.ParseError.self) {
            try OrderedJSON.parse(text)
        }
    }

    // MARK: - Round Trip

    @Test("the reader agrees with JSONSerialization on a fixture file")
    func agreesWithFoundationOnAFixtureFile() throws {
        let url = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/decode/numbers.json")
        let data = try Data(contentsOf: url)

        let ours = try OrderedJSON.parse(data)
        let theirs = try JSONSerialization.jsonObject(with: data)

        guard case let .object(root) = ours, case let .array(tests)? = root["tests"] else {
            Issue.record("The fixture file has no tests array.")
            return
        }
        let count = ((theirs as? [String: Any])?["tests"] as? [Any])?.count
        #expect(tests.count == count)
    }
}
