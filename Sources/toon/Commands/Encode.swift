import ArgumentParser
import Foundation
import ToonFormat

struct Encode: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Convert JSON to TOON format.",
        discussion: """
            Reads JSON from stdin or a file and outputs TOON to stdout.

            Examples:
              echo '{"name":"Ada"}' | toon encode
              toon encode data.json
              toon encode --delimiter tab data.json
              toon encode --key-folding data.json
            """
    )

    @Argument(help: "Input JSON file path. If omitted, reads from stdin.")
    var file: String?

    @Option(name: [.customLong("delimiter"), .customShort("d")], help: "Array delimiter: comma (default), tab, or pipe.")
    var delimiter: DelimiterOption = .comma

    @Option(name: [.customLong("indent"), .customShort("i")], help: "Spaces per indentation level (default: 2).")
    var indent: Int = 2

    @Flag(name: [.customLong("key-folding"), .customShort("k")], help: "Enable key folding.")
    var keyFolding: Bool = false

    @Option(name: .customLong("flatten-depth"), help: "Maximum depth for key folding.")
    var flattenDepth: Int?

    func run() throws {
        let inputData = try readInput(from: file)

        let value = try JSONDecoder().decode(Value.self, from: inputData)

        let encoder = TOONEncoder()
        encoder.indent = indent
        encoder.delimiter = delimiter.toTOON()
        encoder.keyFolding = keyFolding ? .safe : .disabled
        if let depth = flattenDepth {
            encoder.flattenDepth = depth
        }

        let toonData = try encoder.encode(value)

        if let output = String(data: toonData, encoding: .utf8) {
            print(output, terminator: "")
        }
    }
}
