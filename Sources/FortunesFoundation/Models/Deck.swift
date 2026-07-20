import Foundation

enum Deck {
    /// A full 78-card tarot deck (56 minor arcana + 22 major arcana), shuffled.
    static func fullShuffledDeck() -> [Card] {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in MinorRank.allCases {
                cards.append(Card(kind: .minor(suit: suit, rank: rank)))
            }
        }
        for arcana in MajorArcana.allCases {
            cards.append(Card(kind: .major(arcana)))
        }
        cards.shuffle()
        return cards
    }
}
