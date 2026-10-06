import Foundation
import Testing

@testable import ToonFormat

@Suite("Encoder Tests")
struct EncoderTests {
    let encoder = TOONEncoder()

    // MARK: - Primitives

    @Test func specialNumericValues() async throws {
        #expect(String(data: try encoder.encode(-0.0), encoding: .utf8) == "0")
        #expect(String(data: try encoder.encode(Double.nan), encoding: .utf8) == "null")
        #expect(String(data: try encoder.encode(Double.infinity), encoding: .utf8) == "null")
        #expect(String(data: try encoder.encode(-Double.infinity), encoding: .utf8) == "null")
        #expect(String(data: try encoder.encode(1e6), encoding: .utf8) == "1000000")
        #expect(String(data: try encoder.encode(Int64.max), encoding: .utf8) == "9223372036854775807")
    }

    @Test func preserveNegativeZero() async throws {
        let encoder = TOONEncoder()
        encoder.negativeZeroEncodingStrategy = .preserve
        #expect(String(data: try encoder.encode(-0.0), encoding: .utf8) == "-0")
    }

    @Test func nonConformingFloatThrowStrategy() async throws {
        let encoder = TOONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .throw
        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(Double.nan)
        }
        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(Double.infinity)
        }
        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(-Double.infinity)
        }
    }

    @Test func nonConformingFloatConvertToStringStrategy() async throws {
        let encoder = TOONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Inf",
            negativeInfinity: "-Inf",
            nan: "NaN"
        )
        #expect(String(data: try encoder.encode(Double.nan), encoding: .utf8) == "NaN")
        #expect(String(data: try encoder.encode(Double.infinity), encoding: .utf8) == "Inf")
        #expect(String(data: try encoder.encode(-Double.infinity), encoding: .utf8) == "\"-Inf\"")
    }

    @Test func nonConformingFloatThrowStrategyCodingPath() async throws {
        struct Nested: Codable {
            struct Inner: Codable {
                let value: Double
            }
            let values: [Double]
            let inner: Inner
        }

        let encoder = TOONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .throw

        do {
            _ = try encoder.encode([1.0, Double.nan, 2.0])
            #expect(Bool(false))
        } catch EncodingError.invalidValue(_, let context) {
            let path = context.codingPath.map(\.stringValue)
            #expect(path == ["1"])
        } catch {
            #expect(Bool(false))
        }

        do {
            _ = try encoder.encode(Nested(values: [1.0, 2.0], inner: .init(value: Double.infinity)))
            #expect(Bool(false))
        } catch EncodingError.invalidValue(_, let context) {
            let path = context.codingPath.map(\.stringValue)
            #expect(path == ["inner", "value"])
        } catch {
            #expect(Bool(false))
        }
    }

    @Test func nullValues() async throws {
        struct NullTest: Codable {
            let value: String?
        }
        let nullTest = NullTest(value: nil)
        let nullResult = String(data: try encoder.encode(nullTest), encoding: .utf8)!
        #expect(nullResult.contains("value: null"))
    }

    // MARK: - Simple Objects

    @Test func objectWithNullValue() async throws {
        struct NullTestObject: Codable {
            let id: Int
            let value: String?
        }

        let nullObj = NullTestObject(id: 123, value: nil)
        let nullResult = String(data: try encoder.encode(nullObj), encoding: .utf8)!
        #expect(nullResult.contains("id: 123"))
        #expect(nullResult.contains("value: null"))
    }

    @Test func emptyObject() async throws {
        struct EmptyObject: Codable {}
        let emptyResult = String(data: try encoder.encode(EmptyObject()), encoding: .utf8)!
        #expect(emptyResult.isEmpty)
    }

    // MARK: - Object Keys

    @Test func dictionaryKeyOrderingIsDeterministic() async throws {
        let orderedPairs: [(String, Int)] = [
            ("alpha", 1),
            ("bravo", 2),
            ("charlie", 3),
            ("delta", 4),
            ("echo", 5),
            ("foxtrot", 6),
            ("golf", 7),
            ("hotel", 8),
            ("india", 9),
            ("juliet", 10),
            ("kilo", 11),
            ("lima", 12),
            ("mike", 13),
            ("november", 14),
            ("oscar", 15),
            ("papa", 16),
            ("quebec", 17),
            ("romeo", 18),
            ("sierra", 19),
            ("tango", 20),
            ("uniform", 21),
            ("victor", 22),
            ("whiskey", 23),
            ("xray", 24),
            ("yankee", 25),
            ("zulu", 26),
        ]
        let expected =
            orderedPairs
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0): \($0.1)" }
            .joined(separator: "\n")

        let count = orderedPairs.count
        for iteration in 0 ..< 30 {
            var dictionary: [String: Int] = [:]
            let offset = iteration % count
            let rotatedPairs = Array(orderedPairs[offset...]) + Array(orderedPairs[..<offset])
            for (key, value) in rotatedPairs {
                dictionary[key] = value
            }

            let result = String(data: try encoder.encode(dictionary), encoding: .utf8)!
            #expect(result == expected)
        }
    }

    @Test func dictionaryCodingKeyReflectionIsStable() async throws {
        final class DictionaryKeyProbeEncoder: Encoder {
            var codingPath: [CodingKey] = []
            var userInfo: [CodingUserInfoKey: Any] = [:]
            var keyTypeName: String?

            func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
            where Key: CodingKey {
                keyTypeName = String(reflecting: Key.self)
                return KeyedEncodingContainer(ProbeKeyedContainer<Key>())
            }

            func unkeyedContainer() -> UnkeyedEncodingContainer {
                return ProbeUnkeyedContainer()
            }

            func singleValueContainer() -> SingleValueEncodingContainer {
                return ProbeSingleValueContainer()
            }
        }

        struct ProbeKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
            var codingPath: [CodingKey] = []

            mutating func encodeNil(forKey key: Key) throws {}
            mutating func encode(_ value: Bool, forKey key: Key) throws {}
            mutating func encode(_ value: String, forKey key: Key) throws {}
            mutating func encode(_ value: Double, forKey key: Key) throws {}
            mutating func encode(_ value: Float, forKey key: Key) throws {}
            mutating func encode(_ value: Int, forKey key: Key) throws {}
            mutating func encode(_ value: Int8, forKey key: Key) throws {}
            mutating func encode(_ value: Int16, forKey key: Key) throws {}
            mutating func encode(_ value: Int32, forKey key: Key) throws {}
            mutating func encode(_ value: Int64, forKey key: Key) throws {}
            mutating func encode(_ value: UInt, forKey key: Key) throws {}
            mutating func encode(_ value: UInt8, forKey key: Key) throws {}
            mutating func encode(_ value: UInt16, forKey key: Key) throws {}
            mutating func encode(_ value: UInt32, forKey key: Key) throws {}
            mutating func encode(_ value: UInt64, forKey key: Key) throws {}
            mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {}

            mutating func nestedContainer<NestedKey>(
                keyedBy keyType: NestedKey.Type,
                forKey key: Key
            ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
                return KeyedEncodingContainer(ProbeKeyedContainer<NestedKey>())
            }

            mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
                return ProbeUnkeyedContainer()
            }

            mutating func superEncoder() -> Encoder {
                return DictionaryKeyProbeEncoder()
            }

            mutating func superEncoder(forKey key: Key) -> Encoder {
                return DictionaryKeyProbeEncoder()
            }
        }

        struct ProbeUnkeyedContainer: UnkeyedEncodingContainer {
            var codingPath: [CodingKey] = []
            var count: Int = 0

            mutating func encodeNil() throws { count += 1 }
            mutating func encode(_ value: Bool) throws { count += 1 }
            mutating func encode(_ value: String) throws { count += 1 }
            mutating func encode(_ value: Double) throws { count += 1 }
            mutating func encode(_ value: Float) throws { count += 1 }
            mutating func encode(_ value: Int) throws { count += 1 }
            mutating func encode(_ value: Int8) throws { count += 1 }
            mutating func encode(_ value: Int16) throws { count += 1 }
            mutating func encode(_ value: Int32) throws { count += 1 }
            mutating func encode(_ value: Int64) throws { count += 1 }
            mutating func encode(_ value: UInt) throws { count += 1 }
            mutating func encode(_ value: UInt8) throws { count += 1 }
            mutating func encode(_ value: UInt16) throws { count += 1 }
            mutating func encode(_ value: UInt32) throws { count += 1 }
            mutating func encode(_ value: UInt64) throws { count += 1 }
            mutating func encode<T: Encodable>(_ value: T) throws { count += 1 }

            mutating func nestedContainer<NestedKey>(
                keyedBy keyType: NestedKey.Type
            ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
                return KeyedEncodingContainer(ProbeKeyedContainer<NestedKey>())
            }

            mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
                return ProbeUnkeyedContainer()
            }

            mutating func superEncoder() -> Encoder {
                return DictionaryKeyProbeEncoder()
            }
        }

        struct ProbeSingleValueContainer: SingleValueEncodingContainer {
            var codingPath: [CodingKey] = []

            mutating func encodeNil() throws {}
            mutating func encode(_ value: Bool) throws {}
            mutating func encode(_ value: String) throws {}
            mutating func encode(_ value: Double) throws {}
            mutating func encode(_ value: Float) throws {}
            mutating func encode(_ value: Int) throws {}
            mutating func encode(_ value: Int8) throws {}
            mutating func encode(_ value: Int16) throws {}
            mutating func encode(_ value: Int32) throws {}
            mutating func encode(_ value: Int64) throws {}
            mutating func encode(_ value: UInt) throws {}
            mutating func encode(_ value: UInt8) throws {}
            mutating func encode(_ value: UInt16) throws {}
            mutating func encode(_ value: UInt32) throws {}
            mutating func encode(_ value: UInt64) throws {}
            mutating func encode<T: Encodable>(_ value: T) throws {}
        }

        let encoder = DictionaryKeyProbeEncoder()
        try ["a": 1, "b": 2].encode(to: encoder)
        #expect(encoder.keyTypeName?.contains("DictionaryCodingKey") == true)
    }

    // MARK: - Nested Objects

    @Test func nestedContainersFromKeyedContainer() async throws {
        struct Record: Encodable {
            enum Keys: String, CodingKey { case id, meta, tags, empty }
            enum MetaKeys: String, CodingKey { case owner }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: Keys.self)
                try container.encode(1, forKey: .id)
                var meta = container.nestedContainer(keyedBy: MetaKeys.self, forKey: .meta)
                try meta.encode("ada", forKey: .owner)
                var tags = container.nestedUnkeyedContainer(forKey: .tags)
                try tags.encode("a")
                try tags.encode("b")
                _ = container.nestedUnkeyedContainer(forKey: .empty)
            }
        }

        let result = String(data: try encoder.encode(Record()), encoding: .utf8)!
        #expect(result == "id: 1\nmeta:\n  owner: ada\ntags[2]: a,b\nempty: []")
    }

    @Test func nestedContainersFromUnkeyedContainer() async throws {
        struct Pairs: Encodable {
            enum Keys: String, CodingKey { case x }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.unkeyedContainer()
                var first = container.nestedContainer(keyedBy: Keys.self)
                try first.encode(1, forKey: .x)
                var second = container.nestedUnkeyedContainer()
                try second.encode(2)
                try second.encode(3)
                try container.encode(4)
            }
        }

        let result = String(data: try encoder.encode(Pairs()), encoding: .utf8)!
        #expect(result == "[3]:\n  - x: 1\n  - [2]: 2,3\n  - 4")
    }

    // MARK: - Object Arrays

    @Test func tabularFormatWithNullValues() async throws {
        struct NullTabularObject: Codable {
            let id: Int
            let value: String?
        }

        struct NullTabularArrayObject: Codable {
            let items: [NullTabularObject]
        }

        let nullTabularObj = NullTabularArrayObject(items: [
            NullTabularObject(id: 1, value: nil),
            NullTabularObject(id: 2, value: "test"),
        ])
        let nullTabularResult = String(data: try encoder.encode(nullTabularObj), encoding: .utf8)!
        #expect(nullTabularResult.contains("items[2]{id,value}:"))
        #expect(nullTabularResult.contains("  1,null"))
        #expect(nullTabularResult.contains("  2,test"))
    }

    @Test func tabularFieldOrderFromFirstObject() async throws {
        struct OrderedObject: Codable {
            let a: Int
            let b: Int
            let c: Int
        }

        struct OrderedArrayObject: Codable {
            let items: [OrderedObject]
        }

        let orderedObj = OrderedArrayObject(items: [
            OrderedObject(a: 1, b: 2, c: 3),
            OrderedObject(a: 10, b: 20, c: 30),
        ])
        let orderedResult = String(data: try encoder.encode(orderedObj), encoding: .utf8)!
        #expect(orderedResult.contains("items[2]{a,b,c}:"))
        #expect(orderedResult.contains("  1,2,3"))
        #expect(orderedResult.contains("  10,20,30"))
    }

    // MARK: - Mixed Arrays

    @Test func objectsWithOptionalFields() async throws {
        struct OptionalFieldObject: Codable {
            let id: Int
            let name: String
            let extra: Bool?
        }

        struct OptionalFieldArrayObject: Codable {
            let items: [OptionalFieldObject]
        }

        let optionalObj = OptionalFieldArrayObject(items: [
            OptionalFieldObject(id: 1, name: "First", extra: nil),
            OptionalFieldObject(id: 2, name: "Second", extra: true),
        ])
        let optionalResult = String(data: try encoder.encode(optionalObj), encoding: .utf8)!

        #expect(optionalResult.contains("items[2]{id,name,extra}:"))
        #expect(optionalResult.contains("  1,First,null"))
        #expect(optionalResult.contains("  2,Second,true"))
    }

    @Test func nestedListArrayInListFormat() async throws {
        struct NestedListUser: Codable {
            let id: Int
            let name: String?
        }

        struct NestedListInListObject: Codable {
            let users: [NestedListUser]
            let status: String
        }

        struct NestedListInListArrayObject: Codable {
            let items: [NestedListInListObject]
        }

        let nestedListInListObj = NestedListInListArrayObject(items: [
            NestedListInListObject(
                users: [NestedListUser(id: 1, name: "Ada"), NestedListUser(id: 2, name: nil)],
                status: "active"
            )
        ])
        let nestedListInListResult = String(
            data: try encoder.encode(nestedListInListObj),
            encoding: .utf8
        )!
        #expect(nestedListInListResult.contains("items[1]:"))
        #expect(nestedListInListResult.contains("  - users[2]"))
        #expect(nestedListInListResult.contains("    status: active"))
    }

    // MARK: - Indent Size Option

    /// An indentation size below one is a mistake, not a crash.
    ///
    /// A size of zero wrote every line at the left margin, so the output no
    /// longer held the structure. A negative size trapped inside
    /// `String(repeating:count:)` and stopped the host process.
    @Test func anIndentSizeBelowOneIsAnError() async throws {
        for size in [0, -1] {
            let encoder = TOONEncoder()
            encoder.indentSize = size
            #expect(throws: (any Error).self) {
                try encoder.encode(["a": ["b": 1]])
            }
        }
    }

    // MARK: - Root Arrays

    @Test func rootObjectArrayWithOptionalFields() async throws {
        struct OptionalObject: Codable {
            let id: Int
            let name: String?
        }

        let optionalArray = [
            OptionalObject(id: 1, name: nil),
            OptionalObject(id: 2, name: "Ada"),
        ]
        let optionalResult = String(data: try encoder.encode(optionalArray), encoding: .utf8)!
        #expect(optionalResult.contains("[2]{id,name}:"))
        #expect(optionalResult.contains("  1,null"))
        #expect(optionalResult.contains("  2,Ada"))
    }

    // MARK: - Non-JSON-serializable Values

    @Test func dateConversion() async throws {
        let date = Date(timeIntervalSince1970: 0)
        let dateResult = String(data: try encoder.encode(date), encoding: .utf8)!
        #expect(dateResult.contains("\"1970-01-01T00:00:00.000Z\""))

        struct DateObject: Codable {
            let created: Date
        }

        let dateObj = DateObject(created: date)
        let dateObjResult = String(data: try encoder.encode(dateObj), encoding: .utf8)!
        #expect(dateObjResult.contains("created: \"1970-01-01T00:00:00.000Z\""))
    }

    @Test func urlConversion() async throws {
        let url = URL(string: "https://example.com")!
        let urlResult = String(data: try encoder.encode(url), encoding: .utf8)!
        #expect(urlResult.contains("\"https://example.com\""))

        struct URLObject: Codable {
            let url: URL
        }

        let urlObj = URLObject(url: url)
        let urlObjResult = String(data: try encoder.encode(urlObj), encoding: .utf8)!
        #expect(urlObjResult.contains("url: \"https://example.com\""))
    }

    @Test func dataConversion() async throws {
        let data = "hello".data(using: .utf8)!
        let dataResult = String(data: try encoder.encode(data), encoding: .utf8)!
        #expect(dataResult.contains("aGVsbG8="))

        struct DataObject: Codable {
            let data: Data
        }

        let dataObj = DataObject(data: data)
        let dataObjResult = String(data: try encoder.encode(dataObj), encoding: .utf8)!
        #expect(dataObjResult.contains("data: aGVsbG8="))
    }

    @Test func nonFiniteNumbers() async throws {
        let infResult = String(data: try encoder.encode(Double.infinity), encoding: .utf8)!
        #expect(infResult.contains("null"))

        let negInfResult = String(data: try encoder.encode(-Double.infinity), encoding: .utf8)!
        #expect(negInfResult.contains("null"))

        let nanResult = String(data: try encoder.encode(Double.nan), encoding: .utf8)!
        #expect(nanResult.contains("null"))

        struct NonFiniteObject: Codable {
            let value: Double
        }

        let nonFiniteObj = NonFiniteObject(value: Double.infinity)
        let nonFiniteResult = String(data: try encoder.encode(nonFiniteObj), encoding: .utf8)!
        #expect(nonFiniteResult.contains("value: null"))
    }

    @Test func integerTypesConversion() async throws {
        // Swift's Int is a native type, similar to JavaScript's BigInt in behavior
        let largeInt = Int.max
        let largeIntResult = String(data: try encoder.encode(largeInt), encoding: .utf8)!
        #expect(largeIntResult == "9223372036854775807")

        struct IntObject: Codable {
            let id: Int
        }

        let intObj = IntObject(id: 456)
        let intObjResult = String(data: try encoder.encode(intObj), encoding: .utf8)!
        #expect(intObjResult.contains("id: 456"))
    }

    @Test func uint64EncodingBoundaries() async throws {
        struct UInt64Object: Codable {
            let value: UInt64
        }

        let smallResult = String(
            data: try encoder.encode(UInt64Object(value: 42)),
            encoding: .utf8
        )!
        #expect(smallResult == "value: 42")

        let maxInt64Result = String(
            data: try encoder.encode(UInt64Object(value: UInt64(Int64.max))),
            encoding: .utf8
        )!
        #expect(maxInt64Result == "value: 9223372036854775807")

        let aboveInt64Result = String(
            data: try encoder.encode(UInt64Object(value: UInt64(Int64.max) + 1)),
            encoding: .utf8
        )!
        #expect(aboveInt64Result == "value: \"9223372036854775808\"")

        let maxResult = String(
            data: try encoder.encode(UInt64Object(value: UInt64.max)),
            encoding: .utf8
        )!
        #expect(maxResult == "value: \"18446744073709551615\"")
    }

    @Test func uintEncodingAboveInt64Max() async throws {
        struct UIntObject: Codable, Equatable {
            let value: UInt
            let list: [UInt]
        }

        let object = UIntObject(value: UInt.max, list: [1, UInt(Int64.max) + 1])
        let result = String(data: try encoder.encode(object), encoding: .utf8)!
        #expect(result == "value: \"18446744073709551615\"\nlist[2]: 1,\"9223372036854775808\"")

        let decoded = try TOONDecoder().decode(UIntObject.self, from: Data(result.utf8))
        #expect(decoded == object)

        let root = String(data: try encoder.encode(UInt.max), encoding: .utf8)!
        #expect(root == "\"18446744073709551615\"")
    }

    @Test func optionalToNull() async throws {
        // Swift optionals convert to null when nil, similar to JavaScript's undefined → null
        struct OptionalValueObject: Codable {
            let value: String?
        }

        let nilObj = OptionalValueObject(value: nil)
        let nilResult = String(data: try encoder.encode(nilObj), encoding: .utf8)!
        #expect(nilResult.contains("value: null"))

        // Note: Swift does not have exact equivalents for JavaScript's Function or Symbol types
        // These would not be Codable in Swift and would be caught at compile time
    }

    // MARK: - Key Folding Tests (TOON 2.1+)

    @available(*, deprecated)
    @Test func keyFoldingDisabled() async throws {
        struct NestedObject: Codable {
            struct User: Codable {
                struct Profile: Codable {
                    let name: String
                }
                let profile: Profile
            }
            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .disabled

        let obj = NestedObject(user: .init(profile: .init(name: "Ada")))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
            user:
              profile:
                name: Ada
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func keyFoldingSafe() async throws {
        struct NestedObject: Codable {
            struct User: Codable {
                struct Profile: Codable {
                    let name: String
                }
                let profile: Profile
            }
            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = NestedObject(user: .init(profile: .init(name: "Ada")))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
            user.profile.name: Ada
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func keyFoldingWithMultipleFields() async throws {
        struct Config: Codable {
            struct Database: Codable {
                struct Connection: Codable {
                    let host: String
                    let port: Int
                }
                let connection: Connection
            }
            struct API: Codable {
                let key: String
            }
            let database: Database
            let api: API
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = Config(
            database: .init(connection: .init(host: "localhost", port: 5432)),
            api: .init(key: "secret")
        )
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
            database.connection:
              host: localhost
              port: 5432
            api.key: secret
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func keyFoldingStopsAtInvalidIdentifier() async throws {
        // Keys with hyphens cannot be folded
        struct ValidThenInvalid: Codable {
            struct Data: Codable {
                struct UserInfo: Codable {
                    let field1: String

                    enum CodingKeys: String, CodingKey {
                        case field1 = "field-1"
                    }
                }
                let userInfo: UserInfo

                enum CodingKeys: String, CodingKey {
                    case userInfo = "user-info"
                }
            }
            let data: Data
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = ValidThenInvalid(data: .init(userInfo: .init(field1: "value")))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // Should fold "data" but stop at "user-info" because it contains hyphen
        let expected = """
            data:
              "user-info":
                "field-1": value
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func keyFoldingWithArray() async throws {
        struct Container: Codable {
            struct Wrapper: Codable {
                let items: [Int]
            }
            let wrapper: Wrapper
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = Container(wrapper: .init(items: [1, 2, 3]))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
            wrapper.items[3]: 1,2,3
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func versionDeclaration() async throws {
        #expect(toonSpecVersion == "4.3")
    }

    @available(*, deprecated)
    @Test func canonicalNumberFormat() async throws {
        // TOON specification requires canonical decimal form: no trailing fractional zeros
        struct Numbers: Codable {
            let a: Double
            let b: Double
            let c: Double
            let d: Double
        }

        let obj = Numbers(a: 1.5, b: 2.0, c: 0.1, d: 123.456)
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
            a: 1.5
            b: 2
            c: 0.1
            d: 123.456
            """
        #expect(result == expected)
    }

    // MARK: - flattenDepth Tests (TOON 3.0)

    @available(*, deprecated)
    @Test func flattenDepthUnlimited() async throws {
        struct DeepNested: Codable {
            struct Level1: Codable {
                struct Level2: Codable {
                    struct Level3: Codable {
                        let value: Int
                    }
                    let level3: Level3
                }
                let level2: Level2
            }
            let level1: Level1
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = .max  // Unlimited (default)

        let obj = DeepNested(level1: .init(level2: .init(level3: .init(value: 42))))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // All levels should be folded into a single dotted path
        let expected = """
            level1.level2.level3.value: 42
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func flattenDepthLimited() async throws {
        struct DeepNested: Codable {
            struct Level1: Codable {
                struct Level2: Codable {
                    struct Level3: Codable {
                        let value: Int
                    }
                    let level3: Level3
                }
                let level2: Level2
            }
            let level1: Level1
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = 2  // Only fold 2 segments

        let obj = DeepNested(level1: .init(level2: .init(level3: .init(value: 42))))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // Only first 2 levels should be folded
        let expected = """
            level1.level2:
              level3:
                value: 42
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func flattenDepthThree() async throws {
        struct DeepNested: Codable {
            struct Level1: Codable {
                struct Level2: Codable {
                    struct Level3: Codable {
                        let value: Int
                    }
                    let level3: Level3
                }
                let level2: Level2
            }
            let level1: Level1
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = 3

        let obj = DeepNested(level1: .init(level2: .init(level3: .init(value: 42))))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // First 3 levels should be folded
        let expected = """
            level1.level2.level3:
              value: 42
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func flattenDepthOne() async throws {
        // flattenDepth < 2 has no practical folding effect
        struct NestedObject: Codable {
            struct User: Codable {
                let name: String
            }
            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = 1  // No folding effect

        let obj = NestedObject(user: .init(name: "Ada"))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // Should not fold because flattenDepth < 2
        let expected = """
            user:
              name: Ada
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func recursionLimitTriggersOnDeepEncoding() async throws {
        indirect enum NestableValue: Codable, Equatable {
            case int(Int)
            case array([NestableValue])
        }

        struct Container: Codable, Equatable {
            let value: NestableValue
        }

        func makeDeepNest(depth: Int) -> NestableValue {
            var value: NestableValue = .int(1)
            for _ in 0 ..< depth {
                value = .array([value])
            }
            return value
        }

        let encoder = TOONEncoder()
        encoder.limits.maxDepth = 10

        do {
            _ = try encoder.encode(Container(value: makeDeepNest(depth: 20)))
            #expect(Bool(false))
        } catch EncodingError.invalidValue(_, let context) {
            #expect(context.debugDescription.contains("Recursion limit"))
        } catch {
            #expect(Bool(false))
        }
    }

    // MARK: - Collision Avoidance Tests (TOON 3.0)

    @available(*, deprecated)
    @Test func keyFoldingCollisionAvoidance() async throws {
        // Test that folding doesn't create keys that collide with existing siblings
        // The key "a.b" is a literal sibling key, and folding "a" -> {b: 1} would create "a.b"
        // which would collide, so folding should NOT happen
        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        // Create a structure where "a.b" is a literal key at the same level as "a"
        struct CollisionTest: Codable {
            struct Nested: Codable {
                let b: Int
            }
            let ab: Int  // Will be encoded as "a.b" (literal dotted key)
            let a: Nested  // Would be folded to "a.b" if not for collision

            enum CodingKeys: String, CodingKey {
                case ab = "a.b"
                case a
            }
        }

        let obj = CollisionTest(ab: 1, a: .init(b: 2))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // "a" should NOT be folded to "a.b" because "a.b" exists as a sibling
        // Note: "a.b" is a valid unquoted key per spec (pattern allows dots)
        let expected = """
            a.b: 1
            a:
              b: 2
            """
        #expect(result == expected)
    }

    @available(*, deprecated)
    @Test func keyFoldingNoCollision() async throws {
        // Test normal folding when there's no collision
        struct NoCollision: Codable {
            struct A: Codable {
                let b: Int
            }
            let a: A
            let c: Int
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = NoCollision(a: .init(b: 1), c: 2)
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // "a" should be folded to "a.b" since there's no collision
        let expected = """
            a.b: 1
            c: 2
            """
        #expect(result == expected)
    }
}
