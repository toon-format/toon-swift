# TOON Format for Swift

[![CI](https://github.com/toon-format/toon-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/toon-format/toon-swift/actions)
[![Swift Version](https://img.shields.io/badge/swift-6.0+-orange.svg)](https://swift.org)
[![SPEC v4.1](https://img.shields.io/badge/spec-v4.1-fef3c0?labelColor=1b1b1f)](https://github.com/toon-format/spec)
[![License: MIT](https://img.shields.io/badge/license-MIT-fef3c0?labelColor=1b1b1f)](./LICENSE.md)

Compact, human-readable serialization format for LLM contexts with **30-60% token reduction** vs JSON. 
Combines YAML-like indentation with CSV-like tabular arrays. 
Full compatibility with the [official TOON specification](https://github.com/toon-format/spec).

**Key Features:** 
Minimal syntax • 
Tabular arrays for uniform data • 
Array length validation • 
Swift 6.0+ • 
Configurable delimiters • 
Nested field groups • 
Keyed tabular form • 
Comments • 
Strict mode • 
Linux compatibility.

LLM tokens are expensive, and JSON is verbose.
TOON saves tokens while remaining human-readable by
using indentation for structure and a tabular format for uniform data:

**JSON**:

```json
{
  "users": [
    { "id": 1, "name": "Alice", "role": "admin" },
    { "id": 2, "name": "Bob", "role": "user" }
  ]
}
```

**TOON**:

```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
```

For full details on TOON's design, benchmarks, and specification,
see the [TOON specification](https://github.com/toon-format/spec).

## Features

### TOONEncoder

`TOONEncoder` conforms to **TOON specification version 4.1** (2026-07-26)
and implements the following features:

- [x] Canonical number formatting with enough precision to read back exactly
- [x] Escape sequences for strings (`\\`, `\"`, `\n`, `\r`, `\t`, and `\uXXXX` for the other control characters)
- [x] Three delimiter types: comma (default), tab, pipe
- [x] Object key order preservation
- [x] Array order preservation
- [x] Tabular format for uniform object arrays
- [x] Nested field groups that collapse a uniform nested-object column into the header
- [x] Keyed tabular format for an object whose values are uniform objects
- [x] Inline format for primitive arrays
- [x] Expanded list format for nested structures
- [x] Canonical empty-array form (`key: []`)
- [x] Configurable encoding limits for security

### TOONDecoder

`TOONDecoder` conforms to **TOON specification version 4.1** (2026-07-26)
and implements the following features:

- [x] Escape sequence parsing (`\\`, `\"`, `\n`, `\r`, `\t`, `\uXXXX`)
- [x] Comment lines (`#`), removed in a lexical pre-pass
- [x] Byte-order mark removal, CRLF input, trailing-space stripping
- [x] The normative number grammar, so `+5`, `.5`, `0x10` and `NaN` stay strings
- [x] Three delimiter types: comma (default), tab, pipe
- [x] Tabular format parsing with field headers and nested field groups
- [x] Keyed tabular format parsing
- [x] Inline format for primitive arrays
- [x] Expanded list format for nested structures
- [x] Strict mode (default) with the full error surface of section 14
- [x] Key identity by Unicode scalar sequence, so two keys that differ only in normalization form stay apart
- [x] Detailed error reporting with line numbers
- [x] Configurable decoding limits for security

## Requirements

- Swift 6.0+ / Xcode 16+
- iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / tvOS 13.0+ / visionOS 1.0+ / Linux

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/toon-format/toon-swift.git", from: "0.5.0")
]
```

Then add the dependency to your target:

```swift
.target(name: "YourTarget", dependencies: ["ToonFormat"])
```

## Migrating from 0.4.x

Release 0.5.0 moves from TOON specification 3.0 to 4.1. The format changed
between those versions, so the output changes too.

| Change | What to do |
|--------|------------|
| `encoder.indent` is renamed `encoder.indentSize` | Rename the property. The old name still works and warns. |
| The decoder no longer guesses the indentation size | Set `decoder.indentSize` when a document does not use two spaces. |
| `decoder.strict` is new and defaults to `true` | Set `decoder.strict = false` to accept a document that specification 14 rejects. |
| `keyFolding` and `flattenDepth` are deprecated | Specification 4.0 removed key folding. They stay off by default and go away in 2.0. |
| `expandPaths` is deprecated and now defaults to `.disabled` | A dotted key is one literal key. To read a document written with key folding, set `.safe` and re-encode. |
| An empty array is written `key: []`, not `key[0]:` | Nothing; both forms decode. |
| A dictionary of uniform objects is written in the keyed tabular form | Nothing; the form round-trips. |
| `indentSize` below 1 throws | Pass 1 or more. The decoder used to flatten the document, and the encoder used to stop the process. |
| A number that a `Float` or a `UInt64` cannot hold throws | Decode into `Double` or `String` instead. The value used to become an infinity, or to lose its sign check. |
| The line number of an error moved | A test that asserts on a line number needs new values. The number now names the line that carries the defect. |
| Outside strict mode the decoder accepts more | A row of the wrong width and a line after the root value no longer throw, which follows specification 14. |

## Usage

### Quick Start

```swift
import ToonFormat

struct User: Codable {
    let id: Int
    let name: String
    let tags: [String]
    let active: Bool
}

// Encoding
let user = User(
    id: 123,
    name: "Ada",
    tags: ["reading", "gaming"],
    active: true
)

let encoder = TOONEncoder()
let data = try encoder.encode(user)
print(String(data: data, encoding: .utf8)!)
// id: 123
// name: Ada
// tags[2]: reading,gaming
// active: true

// Decoding
let decoder = TOONDecoder()
let decoded = try decoder.decode(User.self, from: data)
print(decoded.name) // "Ada"
```

#### Object Key Ordering

`TOONEncoder` preserves the field order defined by `Encodable` types.
When encoding Swift `Dictionary` values, keys are sorted lexicographically.
This helps ensure deterministic output while preserving semantics of encoded data structures.

> [!NOTE]
> Dictionary key ordering is best-effort and relies on a heuristic
> that may change with Swift internals.

```swift
struct ShoppingList: Codable {
    let name: String
    let itemsAndCounts: [String: Int]
}

let list = ShoppingList(
    name: "Groceries",
    itemsAndCounts: ["cherries": 3, "apple": 1, "banana": 2]
)

let encoder = TOONEncoder()
let data = try encoder.encode(list)
print(String(data: data, encoding: .utf8)!)
// name: Groceries    /* name comes first because it is declared first in the struct */
// itemsAndCounts:
//   apple: 1         /* keys in dictionary are sorted */
//   banana: 2
//   cherries: 3
```

#### Custom Delimiters

Use tab or pipe delimiters for additional token savings:

```swift
struct Item: Codable {
    let sku: String
    let name: String
    let qty: Int
    let price: Double
}

let items = [
    Item(sku: "A1", name: "Widget", qty: 2, price: 9.99),
    Item(sku: "B2", name: "Gadget", qty: 1, price: 14.5)
]

let encoder = TOONEncoder()
encoder.delimiter = .tab  // or .pipe

let data = try encoder.encode(["items": items])
```

Output with tab delimiter:

```
items[2	]{sku	name	qty	price}:
  A1	Widget	2	9.99
  B2	Gadget	1	14.5
```

Output with pipe delimiter:

```
items[2|]{sku|name|qty|price}:
  A1|Widget|2|9.99
  B2|Gadget|1|14.5
```

#### Numeric Normalization

`TOONEncoder` defaults to canonical normalization that matches the spec and the
reference JavaScript implementation. You can override this behavior when you
need to preserve negative zero or handle non-finite values explicitly.

```swift
let encoder = TOONEncoder()
encoder.negativeZeroEncodingStrategy = .preserve
encoder.nonConformingFloatEncodingStrategy = .convertToString(
    positiveInfinity: "Infinity",
    negativeInfinity: "-Infinity",
    nan: "NaN"
)
```

#### Tabular Arrays

Arrays of objects with identical primitive fields use an efficient tabular format:

```swift
struct Item: Codable {
    let sku: String
    let qty: Int
    let price: Double
}

let items = [
    Item(sku: "A1", qty: 2, price: 9.99),
    Item(sku: "B2", qty: 1, price: 14.5)
]

let encoder = TOONEncoder()
let data = try encoder.encode(["items": items])
```

Output:

```
items[2]{sku,qty,price}:
  A1,2,9.99
  B2,1,14.5
```

#### Arrays of Arrays

For arrays containing primitive inner arrays:

```swift
let pairs = [[1, 2], [3, 4]]

let encoder = TOONEncoder()
let data = try encoder.encode(["pairs": pairs])
```

Output:

```
pairs[2]:
  - [2]: 1,2
  - [2]: 3,4
```

#### Nested Field Groups

Specification 9.3 collapses a uniform nested-object column into the header,
while the rows stay flat:

```
orders[2]{id,customer{name,country},total}:
  1,Ada,DK,99
  2,Bob,UK,149
```

#### Keyed Tabular Form

Specification 9.5 gives an object whose values are uniform objects a tabular
form of its own. A Swift dictionary such as `[String: Server]` encodes this
way:

```
servers[2:]{host,port}:
  alpha: a.example.com,8080
  beta: b.example.com,9090
```

#### Comments

A decoder removes a comment line before anything else reads the document. A
comment is a full line whose first character after zero or more spaces is `#`;
there is no inline form. An encoder never writes one.

```
# the rows below are unaffected by this line
users[2]{id,name}:
  1,Ada
  2,Bob
```

#### Key Folding (deprecated)

> [!WARNING]
> TOON specification 4.0 removed key folding, and a decoder now reads a dotted
> key as one literal key. The option still works and stays off by default, so
> the encoder conforms unless you opt out. It is removed in 2.0.
>
> To read a document that an earlier release wrote with key folding, decode it
> with `decoder.expandPaths = .safe`, then encode it again.

Key folding collapses single-key nested objects into dotted paths, reducing indentation and token count:

```swift
struct Config: Codable {
    struct Database: Codable {
        struct Connection: Codable {
            let host: String
            let port: Int
        }
        let connection: Connection
    }
    let database: Database
}

let config = Config(
    database: .init(
        connection: .init(host: "localhost", port: 5432)
    )
)

let encoder = TOONEncoder()
encoder.keyFolding = .safe
let data = try encoder.encode(config)
```

Without key folding:

```
database:
  connection:
    host: localhost
    port: 5432
```

Output with key folding (`encoder.keyFolding = .safe`):

```
database.connection:
  host: localhost
  port: 5432
```

### Encoding Limits

Protect against stack overflow from deeply nested structures:

```swift
let encoder = TOONEncoder()
encoder.limits = TOONEncoder.EncodingLimits(maxDepth: 64)
```

| Limit | Default | Description |
|-------|---------|-------------|
| `maxDepth` | 32 | Maximum nesting depth |

Use `.unlimited` for trusted data only.

### Decoding Limits

Protect against malicious or malformed input:

```swift
let decoder = TOONDecoder()
decoder.limits = TOONDecoder.DecodingLimits(
    maxInputSize: 1024 * 1024,  // 1 MB
    maxDepth: 64,
    maxObjectKeys: 1000,
    maxArrayLength: 10000
)
```

| Limit | Default | Description |
|-------|---------|-------------|
| `maxInputSize` | 10 MB | Maximum input size in bytes |
| `maxDepth` | 32 | Maximum nesting depth |
| `maxObjectKeys` | 10,000 | Maximum keys per object |
| `maxArrayLength` | 100,000 | Maximum elements per array |

Use `.unlimited` for trusted data only.

### Version Information

Check the supported TOON specification version:

```swift
print(toonSpecVersion) // "4.1"
```

## Contributing

Contributions are welcome! 
Please read our [Contributing Guide](CONTRIBUTING.md) for
details on how to get started, 
coding standards, 
and the process for submitting pull requests.

Before contributing, please review:

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [TOON Specification](https://github.com/toon-format/spec/blob/main/SPEC.md)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.
Please report unacceptable behavior to hello@johannschopplich.com.

## Project Status

This library implements **TOON specification version 4.1** (2026-07-26) 
with full encoding and decoding support. 
It satisfies all 538 conformance fixtures published by the specification.

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Documentation

- [📜 TOON Spec](https://github.com/toon-format/spec) - Official specification
- [🐛 Issues](https://github.com/toon-format/toon-swift/issues) - Bug reports and features
- [🤝 Contributing](CONTRIBUTING.md) - Contribution guidelines

## License

MIT License – see [LICENSE.md](LICENSE.md) for details
