import Foundation
import Testing

@testable import ToonFormat

@Suite("Round Trip Tests")
struct RoundTripTests {
    let encoder = TOONEncoder()
    let decoder = TOONDecoder()

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

    @available(*, deprecated)
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
