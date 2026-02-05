import Testing
import Foundation
@testable import ToonFormat

@Test func testNegativeZeroNormalized() throws {
    let negativeZero: Double = -0.0
    let encoder = TOONEncoder()
    // Default is .normalized
    
    let data = try encoder.encode(["value": negativeZero])
    let string = String(data: data, encoding: .utf8)!
    
    // Expect 0, no negative sign
    #expect(string.contains("value: 0"), "Failed to normalize -0: \(string)")
    #expect(!string.contains("value: -0"), "Normalized output contains -0")
}

@Test func testNegativeZeroPreserved() throws {
    let negativeZero: Double = -0.0
    let encoder = TOONEncoder()
    encoder.configuration.minusZeroStrategy = .preserved
    
    let data = try encoder.encode(["value": negativeZero])
    let string = String(data: data, encoding: .utf8)!
    
    // Expect -0
    #expect(string.contains("value: -0"), "Failed to preserve -0: \(string)")
}
