### Description
Fixes #16

`TOONEncoder` encodes `UInt64` values larger than `Int64.max` as strings to ensure precision and avoid JSON/overflow issues. However, `TOONDecoder` previously only attempted to decode `UInt64` from integer tokens.

This PR adds logic to `decodeUInt64` to attempt parsing the value from a string if the initial integer retrieval fails or if the underlying value is a string.

### Changes
*   Modified `Decoder.swift`: Updated `decodeUInt64` to handle string-encoded `UInt64` values.
*   Added `UInt64DecodingTests.swift`: Regression test ensuring round-trip compatibility for large `UInt64` values.

### Verification
*   Added new test case `testUInt64RoundTrip`.
*   Verified that all existing tests pass (`swift test`).
