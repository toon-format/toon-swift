/// The conformance cases that the library does not satisfy yet.
///
/// The key is `<category>/<file>#<index>`, the identifier that
/// ``FixtureCase/id`` builds. The value names the specification section and the
/// case, so that a diff of this file reads as a list of closed gaps.
///
/// ``FixtureTests`` wraps a listed case in `withKnownIssue`, so the run fails
/// when the case starts to pass. Each step of the migration to specification
/// 4.1 removes its own entries, and cannot forget to. The list must be empty
/// for the release.
///
/// Regenerate this file with `Scripts/record-fixture-gaps.sh`.
enum FixtureExpectations {
    static let knownGaps: [String: String] = [:]
}
