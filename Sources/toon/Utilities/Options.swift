import ArgumentParser
import ToonFormat

enum DelimiterOption: String, ExpressibleByArgument, CaseIterable {
    case comma
    case tab
    case pipe

    func toTOON() -> TOONEncoder.Delimiter {
        switch self {
        case .comma: return .comma
        case .tab: return .tab
        case .pipe: return .pipe
        }
    }
}

enum PathExpansionOption: String, ExpressibleByArgument, CaseIterable {
    case automatic
    case disabled
    case safe

    func toTOON() -> TOONDecoder.PathExpansion {
        switch self {
        case .automatic: return .automatic
        case .disabled: return .disabled
        case .safe: return .safe
        }
    }
}
