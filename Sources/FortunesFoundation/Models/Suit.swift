import Foundation

enum Suit: String, CaseIterable, Identifiable, Codable, Hashable {
    case wands, cups, swords, pentacles

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .wands: return "🔥"
        case .cups: return "💧"
        case .swords: return "🗡️"
        case .pentacles: return "☆"
        }
    }

    /// The two suit "colors" used for alternating tableau sequences.
    var color: SuitColor {
        switch self {
        case .wands, .swords: return .crimson
        case .cups, .pentacles: return .indigo
        }
    }
}

enum SuitColor {
    case crimson, indigo
}
