import Foundation
import Testing

@testable import ToonFormat

@Suite("Round Trip Tests")
struct RoundTripTests {
    let encoder = TOONEncoder()
    let decoder = TOONDecoder()

    @Test func roundTripSimpleObject() async throws {
        struct TestObject: Codable, Equatable {
            let id: Int
            let name: String
            let active: Bool
        }

        let original = TestObject(id: 123, name: "Ada", active: true)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(TestObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripTabularArray() async throws {
        struct Item: Codable, Equatable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct Container: Codable, Equatable {
            let items: [Item]
        }

        let original = Container(items: [
            Item(sku: "A1", qty: 2, price: 9.99),
            Item(sku: "B2", qty: 1, price: 14.5),
        ])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(Container.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripNestedObjects() async throws {
        struct DeepNestedObject: Codable, Equatable {
            struct Level2: Codable, Equatable {
                struct Level3: Codable, Equatable {
                    let c: String
                }

                let b: Level3
            }

            let a: Level2
        }

        let original = DeepNestedObject(
            a: DeepNestedObject.Level2(b: DeepNestedObject.Level2.Level3(c: "deep"))
        )
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DeepNestedObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripPrimitiveArrays() async throws {
        struct ArrayObject: Codable, Equatable {
            let tags: [String]
            let nums: [Int]
        }

        let original = ArrayObject(tags: ["reading", "gaming"], nums: [1, 2, 3])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ArrayObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripComplexStructure() async throws {
        struct ComplexObject: Codable, Equatable {
            struct User: Codable, Equatable {
                let id: Int
                let name: String
                let tags: [String]
                let active: Bool
            }

            let user: User
        }

        let original = ComplexObject(
            user: ComplexObject.User(
                id: 123,
                name: "Ada",
                tags: ["reading", "gaming"],
                active: true
            )
        )
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ComplexObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripDate() async throws {
        struct DateObject: Codable, Equatable {
            let created: Date
        }

        let original = DateObject(created: Date(timeIntervalSince1970: 0))
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DateObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripURL() async throws {
        struct URLObject: Codable, Equatable {
            let url: URL
        }

        let original = URLObject(url: URL(string: "https://example.com")!)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(URLObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripData() async throws {
        struct DataObject: Codable, Equatable {
            let data: Data
        }

        let original = DataObject(data: "hello".data(using: .utf8)!)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DataObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripEmptyArray() async throws {
        struct EmptyArrayObject: Codable, Equatable {
            let items: [String]
        }

        let original = EmptyArrayObject(items: [])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(EmptyArrayObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripQuotedStrings() async throws {
        struct QuotedObject: Codable, Equatable {
            let note: String
        }

        let original = QuotedObject(note: "a:b,c")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(QuotedObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripEscapeSequences() async throws {
        struct EscapeObject: Codable, Equatable {
            let text: String
        }

        let original = EscapeObject(text: "line1\nline2\ttab")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(EscapeObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripNullValues() async throws {
        struct NullObject: Codable, Equatable {
            let id: Int
            let value: String?
        }

        let original = NullObject(id: 1, value: nil)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NullObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripOptionalValues() async throws {
        struct OptionalObject: Codable, Equatable {
            let required: String
            let optional: String?
        }

        let original1 = OptionalObject(required: "hello", optional: nil)
        let encoded1 = try encoder.encode(original1)
        let decoded1 = try decoder.decode(OptionalObject.self, from: encoded1)
        #expect(original1 == decoded1)

        let original2 = OptionalObject(required: "hello", optional: "world")
        let encoded2 = try encoder.encode(original2)
        let decoded2 = try decoder.decode(OptionalObject.self, from: encoded2)
        #expect(original2 == decoded2)
    }

    @Test func roundTripTabDelimiter() async throws {
        struct DelimiterObject: Codable, Equatable {
            let tags: [String]
        }

        let encoder = TOONEncoder()
        encoder.delimiter = .tab

        let original = DelimiterObject(tags: ["reading", "gaming", "coding"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DelimiterObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripPipeDelimiter() async throws {
        struct DelimiterObject: Codable, Equatable {
            let tags: [String]
        }

        let encoder = TOONEncoder()
        encoder.delimiter = .pipe

        let original = DelimiterObject(tags: ["reading", "gaming", "coding"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DelimiterObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripKeyFolding() async throws {
        struct NestedObject: Codable, Equatable {
            struct User: Codable, Equatable {
                struct Profile: Codable, Equatable {
                    let name: String
                }

                let profile: Profile
            }

            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let decoder = TOONDecoder()
        decoder.expandPaths = .safe

        let original = NestedObject(user: .init(profile: .init(name: "Ada")))
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NestedObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripArrayOfArrays() async throws {
        struct ArrayOfArraysObject: Codable, Equatable {
            let pairs: [[String]]
        }

        let original = ArrayOfArraysObject(pairs: [["a", "b"], ["c", "d"]])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ArrayOfArraysObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripUnicodeStrings() async throws {
        struct UnicodeObject: Codable, Equatable {
            let text: String
        }

        let original = UnicodeObject(text: "café 你好 🚀")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(UnicodeObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripSpecialKeyNames() async throws {
        struct SpecialKeyObject: Codable, Equatable {
            let orderId: Int
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case orderId = "order:id"
                case fullName = "full name"
            }
        }

        let original = SpecialKeyObject(orderId: 7, fullName: "Ada")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(SpecialKeyObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripMixedArrayFormats() async throws {
        struct MixedObject: Codable, Equatable {
            let id: Int
            let nested: [String: String]
        }

        struct MixedArrayObject: Codable, Equatable {
            let items: [MixedObject]
        }

        let original = MixedArrayObject(items: [
            MixedObject(id: 1, nested: ["x": "1"])
        ])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(MixedArrayObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripEnums() async throws {
        enum Status: String, Codable {
            case active
            case inactive
        }

        struct EnumObject: Codable, Equatable {
            let status: Status
        }

        let original = EnumObject(status: .active)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(EnumObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripNestedOptionalArrays() async throws {
        struct NestedOptional: Codable, Equatable {
            let items: [String?]
        }

        let original = NestedOptional(items: ["a", nil, "b"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NestedOptional.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripUInt64Values() async throws {
        struct Container: Codable, Equatable {
            let value: UInt64
        }

        let values: [UInt64] = [
            0,
            1,
            UInt64(Int64.max),
            UInt64(Int64.max) + 1,
            UInt64.max,
        ]

        for value in values {
            let original = Container(value: value)
            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(Container.self, from: encoded)
            #expect(original == decoded)
        }
    }
}
