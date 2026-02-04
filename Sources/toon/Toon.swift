import ArgumentParser
import ToonFormat

@main
struct Toon: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toon",
        abstract: "Convert between JSON and TOON formats.",
        discussion: """
            TOON (Token-Oriented Object Notation) is a compact, human-readable
            serialization format optimized for LLM contexts with 30-60% token
            reduction vs JSON.

            Spec: https://github.com/toon-format/spec
            """,
        version: "0.3.0 (TOON spec \(toonSpecVersion))",
        subcommands: [Encode.self, Decode.self]
    )
}
