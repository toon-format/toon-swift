import Foundation

func readInput(from filePath: String?) throws -> Data {
    if let path = filePath {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }

    var data = Data()
    while let line = readLine(strippingNewline: false) {
        if let lineData = line.data(using: .utf8) {
            data.append(lineData)
        }
    }
    return data
}
