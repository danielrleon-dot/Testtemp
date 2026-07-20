import Foundation

enum CardKind: Hashable, Codable {
    case colour(Colour, ColourRank)
    case trump(Int)
}

struct Card: Identifiable, Hashable, Codable {
    let id: UUID
    let kind: CardKind

    init(kind: CardKind) {
        self.id = UUID()
        self.kind = kind
    }

    var rankValue: Int {
        switch kind {
        case .colour(_, let rank): return rank.rawValue
        case .trump(let n): return n
        }
    }

    var isTrump: Bool {
        if case .trump = kind { return true }
        return false
    }

    var colour: Colour? {
        if case .colour(let colour, _) = kind { return colour }
        return nil
    }

    var shortLabel: String {
        switch kind {
        case .colour(let colour, let rank):
            return "\(rank.label)\(colour.shortCode)"
        case .trump(let n):
            return "\(n)"
        }
    }

    var displayLabel: String {
        switch kind {
        case .colour(let colour, let rank):
            return "\(rank.label) of \(colour.label)"
        case .trump(let n):
            return "Trump \(n)"
        }
    }
}
