import Foundation

enum MinorRank: Int, CaseIterable, Codable, Hashable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten
    case page = 11, knight = 12, queen = 13, king = 14

    var label: String {
        switch self {
        case .ace: return "Ace"
        case .page: return "Page"
        case .knight: return "Knight"
        case .queen: return "Queen"
        case .king: return "King"
        default: return "\(rawValue)"
        }
    }
}
