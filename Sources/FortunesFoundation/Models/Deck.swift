import Foundation

enum Deck {
    /// 4 colours x (2...King) + trumps (0...21) = 70 cards, shuffled
    /// deterministically from `seed` so a deal can be reproduced later.
    /// See RULES.md.
    static func fullShuffledDeck(seed: UInt64) -> [Card] {
        var cards: [Card] = []
        for colour in Colour.allCases {
            for rank in ColourRank.allCases {
                cards.append(Card(kind: .colour(colour, rank)))
            }
        }
        for n in 0...21 {
            cards.append(Card(kind: .trump(n)))
        }
        var rng = SeededGenerator(seed: seed)
        cards.shuffle(using: &rng)
        return cards
    }
}
