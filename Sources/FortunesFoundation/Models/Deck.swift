import Foundation

enum Deck {
    /// 4 colours x (2...King) + trumps (0...21) = 70 cards, shuffled. See RULES.md.
    static func fullShuffledDeck() -> [Card] {
        var cards: [Card] = []
        for colour in Colour.allCases {
            for rank in ColourRank.allCases {
                cards.append(Card(kind: .colour(colour, rank)))
            }
        }
        for n in 0...21 {
            cards.append(Card(kind: .trump(n)))
        }
        cards.shuffle()
        return cards
    }
}
