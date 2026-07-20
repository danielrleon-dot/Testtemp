import Foundation

/// 2 through King, no Aces (see RULES.md).
enum ColourRank: Int, CaseIterable, Codable, Hashable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    var label: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return "\(rawValue)"
        }
    }
}
