import Foundation

enum CardKind: Hashable, Codable {
    case minor(suit: Suit, rank: MinorRank)
    case major(MajorArcana)
}

struct Card: Identifiable, Hashable, Codable {
    let id: UUID
    let kind: CardKind
    var isFaceUp: Bool = false

    init(kind: CardKind, isFaceUp: Bool = false) {
        self.id = UUID()
        self.kind = kind
        self.isFaceUp = isFaceUp
    }

    var displayLabel: String {
        switch kind {
        case .minor(let suit, let rank):
            return "\(rank.label) of \(suit.rawValue.capitalized)"
        case .major(let arcana):
            return arcana.name
        }
    }

    var shortLabel: String {
        switch kind {
        case .minor(let suit, let rank):
            let rankText: String
            switch rank {
            case .ace: rankText = "A"
            case .page: rankText = "P"
            case .knight: rankText = "Kn"
            case .queen: rankText = "Q"
            case .king: rankText = "K"
            default: rankText = "\(rank.rawValue)"
            }
            return "\(rankText)\(suit.symbol)"
        case .major(let arcana):
            return "\(arcana.rawValue)"
        }
    }

    var suitColor: SuitColor? {
        if case .minor(let suit, _) = kind { return suit.color }
        return nil
    }

    var isMajor: Bool {
        if case .major = kind { return true }
        return false
    }
}
