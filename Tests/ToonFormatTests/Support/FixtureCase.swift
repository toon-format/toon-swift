import Foundation
import Testing

@testable import ToonFormat

/// One case from the conformance fixtures of the TOON specification.
///
/// The fixtures live in `Tests/ToonFormatTests/Fixtures`, copied from
/// `toon-format/spec` by `Scripts/update-fixtures.sh`.
///
/// The `README.md` of the fixtures states that `name`, `description` and `note`
/// are prose, not identifiers. A runner must key on the file path and the array
/// index. This type therefore identifies a case by ``file`` and ``index``, and
/// uses ``name`` only for the display string.
struct FixtureCase: Sendable, CustomTestStringConvertible {
    /// The path inside the fixtures directory, such as `decode/numbers.json`.
    let file: String
    /// The position in the `tests` array of the file.
    let index: Int
    let name: String
    let input: TOONValue
    let expected: TOONValue
    let shouldError: Bool
    let options: FixtureOptions
    let specSection: String?
    let note: String?
    let minSpecVersion: SpecVersion?

    /// The identifier that ``FixtureExpectations`` uses.
    var id: String { "\(file)#\(index)" }

    var testDescription: String { "\(id) — \(name)" }
}

struct FixtureOptions: Sendable {
    var delimiter: TOONEncoder.Delimiter = .comma
    var indentSize: Int = 2
    var strict: Bool = true
}

/// A `MAJOR.MINOR` version of the specification.
struct SpecVersion: Comparable, Sendable, CustomStringConvertible {
    let major: Int
    let minor: Int

    init?(_ text: String) {
        let parts = text.split(separator: ".")
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else {
            return nil
        }
        self.major = major
        self.minor = minor
    }

    static func < (lhs: SpecVersion, rhs: SpecVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    var description: String { "\(major).\(minor)" }
}

// MARK: - Loading

enum Fixtures {
    static let encode: [FixtureCase] = load(category: "encode")
    static let decode: [FixtureCase] = load(category: "decode")

    /// The version recorded by `Scripts/update-fixtures.sh`.
    static let provenance: TOONObject = {
        let url = directory.appendingPathComponent("PROVENANCE.json")
        guard let data = try? Data(contentsOf: url),
            case let .object(object)? = try? OrderedJSON.parse(data)
        else {
            return TOONObject()
        }
        return object
    }()

    private static let directory: URL = {
        guard let resourceURL = Bundle.module.resourceURL else {
            fatalError("The test bundle has no resource directory.")
        }
        return resourceURL.appendingPathComponent("Fixtures")
    }()

    private static func load(category: String) -> [FixtureCase] {
        let categoryURL = directory.appendingPathComponent(category)
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: categoryURL,
                includingPropertiesForKeys: nil
            )
        } catch {
            fatalError("Cannot list \(categoryURL.path): \(error)")
        }

        return
            contents
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .flatMap { url -> [FixtureCase] in
                let relativePath = "\(category)/\(url.lastPathComponent)"
                do {
                    return try cases(inFileAt: url, relativePath: relativePath)
                } catch {
                    fatalError("Cannot read the fixture file \(relativePath): \(error)")
                }
            }
    }

    private static func cases(inFileAt url: URL, relativePath: String) throws -> [FixtureCase] {
        let data = try Data(contentsOf: url)
        guard case let .object(root) = try OrderedJSON.parse(data),
            case let .array(tests)? = root["tests"]
        else {
            throw FixtureLoadError.malformed(relativePath)
        }

        return try tests.enumerated().map { index, entry in
            guard case let .object(test) = entry,
                case let .string(name)? = test["name"],
                let input = test["input"],
                let expected = test["expected"]
            else {
                throw FixtureLoadError.malformedCase(relativePath, index)
            }

            var options = FixtureOptions()
            if case let .object(rawOptions)? = test["options"] {
                if case let .string(delimiter)? = rawOptions["delimiter"] {
                    guard let parsed = TOONEncoder.Delimiter(rawValue: delimiter) else {
                        throw FixtureLoadError.malformedCase(relativePath, index)
                    }
                    options.delimiter = parsed
                }
                if case let .int(indentSize)? = rawOptions["indentSize"] {
                    options.indentSize = Int(indentSize)
                }
                if case let .bool(strict)? = rawOptions["strict"] {
                    options.strict = strict
                }
            }

            var shouldError = false
            if case let .bool(flag)? = test["shouldError"] {
                shouldError = flag
            }

            var specSection: String?
            if case let .string(section)? = test["specSection"] {
                specSection = section
            }

            var note: String?
            if case let .string(text)? = test["note"] {
                note = text
            }

            var minSpecVersion: SpecVersion?
            if case let .string(version)? = test["minSpecVersion"] {
                minSpecVersion = SpecVersion(version)
            }

            return FixtureCase(
                file: relativePath,
                index: index,
                name: name,
                input: input,
                expected: expected,
                shouldError: shouldError,
                options: options,
                specSection: specSection,
                note: note,
                minSpecVersion: minSpecVersion
            )
        }
    }

    enum FixtureLoadError: Error, CustomStringConvertible {
        case malformed(String)
        case malformedCase(String, Int)

        var description: String {
            switch self {
            case let .malformed(file):
                return "\(file) does not match the fixture schema"
            case let .malformedCase(file, index):
                return "\(file)#\(index) does not match the fixture schema"
            }
        }
    }
}

// MARK: - Equality of the JSON data model

/// Compares two values by the JSON data model of TOON specification § 2.
///
/// The rules that differ from the synthesized `==`:
///
/// - `-0` equals `0`.
/// - A whole `Double` equals the same `Int64`, because the fixtures carry one
///   JSON number type and the library keeps integers and fractions apart.
/// - Strings compare by Unicode scalar sequence, with no normalization.
/// - Objects compare without regard to the order of the keys. The fixtures
///   cannot express the order of the keys of the expected value, so the
///   reference runner ignores it too. Local tests cover the order that
///   § 9.3 and § 9.5 require of a decoder.
func jsonModelEquals(_ lhs: TOONValue, _ rhs: TOONValue) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null):
        return true
    case let (.bool(left), .bool(right)):
        return left == right
    case let (.string(left), .string(right)):
        return left.unicodeScalars.elementsEqual(right.unicodeScalars)
    case let (.int(left), .int(right)):
        return left == right
    case let (.double(left), .double(right)):
        return left == right || (left.isZero && right.isZero)
    case let (.int(left), .double(right)), let (.double(right), .int(left)):
        return right == Double(left)
    case let (.array(left), .array(right)):
        return left.count == right.count
            && zip(left, right).allSatisfy { jsonModelEquals($0, $1) }
    case let (.object(left), .object(right)):
        guard left.count == right.count else { return false }
        return left.allSatisfy { element in
            guard let counterpart = right[element.key] else { return false }
            return jsonModelEquals(element.value, counterpart)
        }
    default:
        return false
    }
}
