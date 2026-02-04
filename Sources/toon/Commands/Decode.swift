import ArgumentParser
import Foundation
import ToonFormat

struct Decode: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Convert TOON to JSON format.",
        discussion: """
            Reads TOON from stdin or a file and outputs JSON to stdout.

            Examples:
              echo 'name: Ada' | toon decode
              toon decode data.toon
              toon decode --pretty data.toon
              toon decode --expand-paths disabled data.toon
            """
    )

    @Argument(help: "Input TOON file path. If omitted, reads from stdin.")
    var file: String?

    @Option(name: .customLong("expand-paths"), help: "Path expansion: automatic (default), disabled, or safe.")
    var expandPaths: PathExpansionOption = .automatic

    @Flag(name: [.customLong("pretty"), .customShort("p")], help: "Pretty-print JSON output.")
    var pretty: Bool = false

    @Flag(name: .customLong("compact"), help: "Compact JSON output.")
    var compact: Bool = false

    func run() throws {
        let inputData = try readInput(from: file)

        let decoder = TOONDecoder()
        decoder.expandPaths = expandPaths.toTOON()

        let value = try decoder.decode(Value.self, from: inputData)

        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        } else if compact {
            encoder.outputFormatting = []
        } else {
            encoder.outputFormatting = .sortedKeys
        }

        let jsonData = try encoder.encode(value)

        if let output = String(data: jsonData, encoding: .utf8) {
            print(output)
        }
    }
}
