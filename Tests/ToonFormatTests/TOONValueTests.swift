import Foundation
import Testing

@testable import ToonFormat

/// Tests the untyped value model.
///
/// ``TOONValue`` and ``TOONObject`` became public with specification 4.1, so
/// their behaviour is part of the released interface. The conformance suite
/// exercises them. It compares one object against another through the same
/// subscript, so a fault in the identity of a key stays invisible there.
@Suite("TOON value model")
struct TOONValueTests {

    // MARK: - Key Identity

    /// Specification 2 and 16 make two keys the same key only when their
    /// Unicode scalar sequences are equal. Swift compares a `String` by
    /// canonical equivalence, so a plain dictionary merges the two forms.
    @Test("two keys that differ only in normalization form stay apart")
    func normalizationFormsStayApart() {
        let composed = "\u{00E9}"
        let decomposed = "e\u{0301}"

        var object = TOONObject()
        object[composed] = .int(1)
        object[decomposed] = .int(2)

        #expect(object.count == 2)
        #expect(object[composed] == .int(1))
        #expect(object[decomposed] == .int(2))
        #expect(object.keys == [composed, decomposed])
    }

    @Test("two objects that differ only in normalization form are different")
    func objectsWithDifferentFormsAreNotEqual() {
        let first: TOONObject = ["\u{00E9}": .int(1)]
        let second: TOONObject = ["e\u{0301}": .int(1)]

        #expect(first != second)
        #expect(first.hashValue != second.hashValue)
    }

    // MARK: - Order

    @Test("the object keeps the order of insertion")
    func keepsInsertionOrder() {
        var object = TOONObject()
        for key in ["z", "a", "m"] {
            object[key] = .null
        }
        #expect(object.keys == ["z", "a", "m"])
        #expect(object.map(\.key) == ["z", "a", "m"])
    }

    /// The rule of specification 14.3 for a decoder that is not strict: the
    /// value comes from the last pair, and the position from the first.
    @Test("a repeated key takes the last value and the first position")
    func repeatedKeyKeepsTheFirstPosition() {
        var object: TOONObject = ["a": .int(1), "b": .int(2)]
        object["a"] = .int(3)

        #expect(object.keys == ["a", "b"])
        #expect(object["a"] == .int(3))

        let literal: TOONObject = ["a": .int(1), "b": .int(2), "a": .int(3)]
        #expect(literal.keys == ["a", "b"])
        #expect(literal["a"] == .int(3))
    }

    @Test("a removal keeps the order of the keys that stay")
    func removalKeepsTheOrderOfTheRest() {
        var object: TOONObject = ["a": .int(1), "b": .int(2), "c": .int(3), "d": .int(4)]

        object["b"] = nil

        #expect(object.keys == ["a", "c", "d"])
        #expect(object.values == [.int(1), .int(3), .int(4)])
        #expect(object.count == 3)

        // The index of every key that stays must still find its own value.
        for position in object.indices {
            #expect(object[object[position].key] == object[position].value)
        }

        object["e"] = .int(5)
        #expect(object.keys == ["a", "c", "d", "e"])
        #expect(object["e"] == .int(5))
    }

    @Test("a missing key gives nil, and a removal of one changes nothing")
    func aMissingKeyGivesNil() {
        var object: TOONObject = ["a": .int(1)]

        #expect(object["b"] == nil)
        object["b"] = nil
        #expect(object.keys == ["a"])
    }

    // MARK: - Equality

    @Test("equality holds the order of the keys")
    func equalityHoldsTheOrder() {
        let first: TOONObject = ["a": .int(1), "b": .int(2)]
        let second: TOONObject = ["b": .int(2), "a": .int(1)]

        #expect(first != second)
    }

    @Test("a hash agrees with equality")
    func hashAgreesWithEquality() {
        let first: TOONObject = ["a": .int(1), "b": .array([.string("x")])]
        let second: TOONObject = ["a": .int(1), "b": .array([.string("x")])]

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(Set([TOONValue.object(first)]).contains(.object(second)))
    }

    // MARK: - Round Trip

    @Test("a document survives a round trip through TOON")
    func survivesARoundTrip() throws {
        let document = TOONValue.object([
            "name": .string("Ada"),
            "tags": .array([.string("a"), .string("b")]),
            "score": .double(0.5),
            "count": .int(3),
            "ok": .bool(true),
            "missing": .null,
            "nested": .object(["x": .int(1)]),
        ])

        let data = try TOONEncoder().encode(document)
        let back = try TOONDecoder().decode(TOONValue.self, from: data)

        #expect(back == document)
    }

    @Test("the order of the keys survives a round trip through TOON")
    func keyOrderSurvivesARoundTrip() throws {
        let document = TOONValue.object(["z": .int(1), "a": .int(2), "m": .int(3)])

        let data = try TOONEncoder().encode(document)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text == "z: 1\na: 2\nm: 3")

        let back = try TOONDecoder().decode(TOONValue.self, from: data)
        guard case let .object(object) = back else {
            Issue.record("Expected an object, got \(back)")
            return
        }
        #expect(object.keys == ["z", "a", "m"])
    }

    /// The type carries `Codable`, so it also travels through `JSONEncoder`.
    /// `JSONDecoder` does not report the order of the keys, so only the
    /// content survives that path.
    @Test("the content survives a round trip through JSON")
    func contentSurvivesARoundTripThroughJSON() throws {
        let document = TOONValue.array([
            .int(1), .string("two"), .bool(false), .null, .object(["k": .double(1.5)]),
        ])

        let data = try JSONEncoder().encode(document)
        let back = try JSONDecoder().decode(TOONValue.self, from: data)

        #expect(back == document)
    }
}
