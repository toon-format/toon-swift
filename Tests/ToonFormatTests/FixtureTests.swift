import Foundation
import Testing

@testable import ToonFormat

/// Runs the conformance fixtures of the TOON specification.
///
/// Run the suite with `swift test --filter FixtureTests`, or one side of it
/// with `swift test --filter encodeFixture` or `--filter decodeFixture`. The
/// `--filter` option matches the name of a suite or of a test function. It does
/// not match the name of a case, so it cannot select one fixture. To follow one
/// case, run the suite and read the identifier that a failure prints, for
/// example `decode/numbers.json#5`.
///
/// A case that the library does not satisfy yet is listed in
/// ``FixtureExpectations/knownGaps``. The suite wraps such a case in
/// `withKnownIssue`, which makes the run fail when the case starts to pass. A
/// step of the migration therefore has to remove its own entries from that
/// list, and cannot forget to.
@Suite("Specification fixtures")
struct FixtureTests {
    @Test("encode", arguments: Fixtures.encode)
    func encodeFixture(_ fixture: FixtureCase) throws {
        try withKnownIssue(fixture.gapComment, isIntermittent: false) {
            let encoder = TOONEncoder()
            encoder.delimiter = fixture.options.delimiter
            encoder.indentSize = fixture.options.indentSize

            guard !fixture.shouldError else {
                #expect(throws: (any Error).self) {
                    try encoder.encode(fixture.input)
                }
                return
            }

            guard case let .string(expected) = fixture.expected else {
                Issue.record("The expected value of an encode case must be a string.")
                return
            }

            let data = try encoder.encode(fixture.input)
            let actual = String(decoding: data, as: UTF8.self)
            #expect(actual == expected)
        } when: {
            FixtureExpectations.knownGaps[fixture.id] != nil
        }
    }

    @Test("decode", arguments: Fixtures.decode)
    func decodeFixture(_ fixture: FixtureCase) throws {
        try withKnownIssue(fixture.gapComment, isIntermittent: false) {
            guard case let .string(source) = fixture.input else {
                Issue.record("The input of a decode case must be a string.")
                return
            }

            let decoder = TOONDecoder()
            decoder.indentSize = fixture.options.indentSize
            decoder.strict = fixture.options.strict
            let data = Data(source.utf8)

            guard !fixture.shouldError else {
                #expect(throws: (any Error).self) {
                    try decoder.decode(TOONValue.self, from: data)
                }
                return
            }

            let actual = try decoder.decode(TOONValue.self, from: data)
            #expect(
                jsonModelEquals(actual, fixture.expected),
                "decoded \(actual), expected \(fixture.expected)"
            )
        } when: {
            FixtureExpectations.knownGaps[fixture.id] != nil
        }
    }

    /// The case count of every fixture file.
    ///
    /// A total on its own does not guard the corpus. A case that moves from one
    /// file to another keeps the total. A whole group can shrink while another
    /// group grows. The counts are per file for that reason.
    private static let expectedCounts: [String: Int] = [
        "decode/arrays-nested.json": 25,
        "decode/arrays-primitive.json": 19,
        "decode/arrays-tabular.json": 18,
        "decode/blank-lines.json": 21,
        "decode/comments.json": 19,
        "decode/delimiters.json": 29,
        "decode/indentation-errors.json": 19,
        "decode/numbers.json": 28,
        "decode/objects-keyed.json": 19,
        "decode/objects.json": 55,
        "decode/primitives.json": 28,
        "decode/root-form.json": 8,
        "decode/validation-errors.json": 56,
        "decode/whitespace.json": 15,
        "encode/arrays-nested.json": 15,
        "encode/arrays-objects.json": 18,
        "encode/arrays-primitive.json": 13,
        "encode/arrays-tabular.json": 16,
        "encode/delimiters.json": 22,
        "encode/objects-keyed.json": 13,
        "encode/objects.json": 34,
        "encode/primitives.json": 44,
        "encode/whitespace.json": 4,
    ]

    /// Guards against a partial or stale copy of the fixtures.
    ///
    /// The test fails after `Scripts/update-fixtures.sh` brings a new release
    /// of the specification. That is the intent: a change of the corpus needs
    /// a reader, not a silent pass.
    @Test("the fixture corpus is complete")
    func corpusIsComplete() {
        var counts: [String: Int] = [:]
        for fixture in Fixtures.encode + Fixtures.decode {
            counts[fixture.file, default: 0] += 1
        }
        #expect(counts == Self.expectedCounts)

        #expect(Fixtures.encode.count == 179)
        #expect(Fixtures.decode.count == 359)
    }

    /// Guards against a corpus taken from another release.
    ///
    /// ``toonSpecVersion`` and the tag of the fixtures must name the same
    /// release. `Scripts/update-fixtures.sh` says that a test makes this
    /// check, and this is that test.
    @Test("the fixtures come from the release the library targets")
    func provenanceMatchesTheTargetVersion() {
        #expect(Fixtures.provenance["repo"] == .string("toon-format/spec"))
        #expect(Fixtures.provenance["source"] == .string("tests/fixtures"))

        guard case let .string(ref)? = Fixtures.provenance["ref"] else {
            Issue.record("PROVENANCE.json carries no ref.")
            return
        }
        // The tag adds a patch number to the version of the specification,
        // so `4.1` targets a tag such as `v4.1.1`.
        #expect(ref.hasPrefix("v\(toonSpecVersion)."))

        guard case let .string(sha)? = Fixtures.provenance["sha"] else {
            Issue.record("PROVENANCE.json carries no sha.")
            return
        }
        #expect(sha.count == 40)
    }
}

extension FixtureCase {
    /// The reason that ``FixtureExpectations`` records for a known gap.
    fileprivate var gapComment: Comment {
        Comment(rawValue: FixtureExpectations.knownGaps[id] ?? "")
    }
}
