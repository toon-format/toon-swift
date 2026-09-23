import Foundation
import Testing

@testable import ToonFormat

/// Checks the encoder against the reference implementation.
///
/// The expected text is the output of `@toon-format/cli` 4.1.1 for the same
/// document, byte for byte. The conformance fixtures cover each rule on its
/// own. This case covers several of the specification 4.1 forms together in one
/// document, the way a real document mixes them.
@Suite("Cross-check with the reference implementation")
struct CrossCheckTests {
    private static let json = """
        {"servers":{"alpha":{"host":"a.example.com","port":8080},\
        "beta":{"host":"b.example.com","port":9090}},\
        "orders":[{"id":1,"customer":{"name":"Ada","country":"DK"},"total":99},\
        {"id":2,"customer":{"name":"Bob","country":"UK"},"total":149}],\
        "tags":["a","b,c","d:e"],"empty":[],"note":"#hash","num":0.3333333333333333}
        """

    private static let expected = """
        servers[2:]{host,port}:
          alpha: a.example.com,8080
          beta: b.example.com,9090
        orders[2]{id,customer{name,country},total}:
          1,Ada,DK,99
          2,Bob,UK,149
        tags[3]: a,"b,c","d:e"
        empty: []
        note: "#hash"
        num: 0.3333333333333333
        """

    @Test("the encoder matches the reference output")
    func encodesLikeTheReference() throws {
        let value = try OrderedJSON.parse(Self.json)
        let actual = String(decoding: try TOONEncoder().encode(value), as: UTF8.self)
        #expect(actual == Self.expected)
    }

    @Test("the document survives a round trip")
    func roundTripsTheReferenceDocument() throws {
        let value = try OrderedJSON.parse(Self.json)
        let decoded = try TOONDecoder().decode(TOONValue.self, from: Self.expected)
        #expect(jsonModelEquals(decoded, value))
    }
}
