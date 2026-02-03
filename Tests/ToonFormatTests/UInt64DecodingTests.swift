import XCTest
@testable import ToonFormat

final class UInt64DecodingTests: XCTestCase {
    
    func testUInt64RoundTrip() throws {
        // value > Int64.max ensures it is encoded as a string by TOONEncoder
        let largeUInt: UInt64 = UInt64(Int64.max) + 500
        
        // Encode
        let encoder = TOONEncoder()
        let data = try encoder.encode(["value": largeUInt])
        
        // Decode
        let decoder = TOONDecoder()
        struct Container: Codable {
            let value: UInt64
        }
        
        do {
            let decoded = try decoder.decode(Container.self, from: data)
            XCTAssertEqual(decoded.value, largeUInt)
        } catch {
            XCTFail("Failed to decode large UInt64: \(error)")
        }
    }
}
