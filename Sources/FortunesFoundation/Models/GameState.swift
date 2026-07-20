import Foundation
import Combine

enum PileLocation: Hashable {
    case tableau(Int)
    case waste
    case stock
    case foundationMinor(Suit)
    case foundationMajor
}

/// Game rules (this app's own tarot-solitaire variant):
/// - 78-card deck dealt into 8 tableau columns (1...8 cards), rest to the stock.
/// - Tableau minor-arcana cards build downward in alternating suit color; a valid
///   descending run can be moved together. Major arcana cards are "dead ends" in the
///   tableau: nothing may be stacked on them, and they may only move to an empty
///   column or straight to the major arcana foundation.
/// - Four minor foundations build Ace -> King per suit. One major foundation builds
///   The Fool (0) -> The World (21).
/// - Win when all 78 cards are on foundations.
final class GameState: ObservableObject {
    @Published var tableau: [[Card]] = []
    @Published var stock: [Card] = []
    @Published var waste: [Card] = []
    @Published var minorFoundations: [Suit: [Card]] = [:]
    @Published var majorFoundation: [Card] = []
    @Published var selection: Selection? = nil
    @Published var moveCount: Int = 0
    @Published var isWon: Bool = false

    struct Selection: Equatable {
        let location: PileLocation
        let cardIDs: [UUID]
    }

    init() {
        newGame()
    }

    // MARK: - Setup

    func newGame() {
        var deck = Deck.fullShuffledDeck()
        tableau = Array(repeating: [], count: 8)
        for col in 0..<8 {
            for _ in 0...col {
                guard var card = deck.popLast() else { continue }
                card.isFaceUp = false
                tableau[col].append(card)
            }
            if !tableau[col].isEmpty {
                tableau[col][tableau[col].count - 1].isFaceUp = true
            }
        }
        stock = deck
        waste = []
        minorFoundations = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, []) })
        majorFoundation = []
        selection = nil
        moveCount = 0
        isWon = false
    }

    // MARK: - Stock

    func drawFromStock() {
        if let card = stock.popLast() {
            var flipped = card
            flipped.isFaceUp = true
            waste.append(flipped)
        } else if !waste.isEmpty {
            stock = waste.reversed().map { card in
                var c = card
                c.isFaceUp = false
                return c
            }
            waste = []
        }
        clearSelection()
    }

    // MARK: - Interaction

    func selectCard(at location: PileLocation, cardID: UUID) {
        if let current = selection {
            if current.location == location, current.cardIDs.contains(cardID) {
                clearSelection()
                return
            }
            if attemptMove(from: current, to: location) {
                clearSelection()
                return
            }
        }
        guard let run = movableRun(at: location, cardID: cardID) else {
            clearSelection()
            return
        }
        selection = Selection(location: location, cardIDs: run)
    }

    func selectPile(_ location: PileLocation) {
        if case .stock = location {
            drawFromStock()
            return
        }
        guard let current = selection else { return }
        _ = attemptMove(from: current, to: location)
        clearSelection()
    }

    private func clearSelection() {
        selection = nil
    }

    // MARK: - Move validation

    private func movableRun(at location: PileLocation, cardID: UUID) -> [UUID]? {
        switch location {
        case .waste:
            guard let top = waste.last, top.id == cardID else { return nil }
            return [top.id]
        case .tableau(let col):
            guard let idx = tableau[col].firstIndex(where: { $0.id == cardID }) else { return nil }
            let run = tableau[col][idx...]
            guard run.first?.isFaceUp == true else { return nil }
            var previous: Card? = nil
            for card in run {
                if !card.isFaceUp { return nil }
                if let previous {
                    guard case .minor(let prevSuit, let prevRank) = previous.kind,
                          case .minor(let suit, let rank) = card.kind,
                          suit.color != prevSuit.color,
                          rank.rawValue == prevRank.rawValue - 1 else {
                        return nil
                    }
                }
                previous = card
            }
            return run.map { $0.id }
        case .foundationMinor, .foundationMajor, .stock:
            return nil
        }
    }

    private func canPlace(cards: [Card], on destination: PileLocation) -> Bool {
        guard let first = cards.first else { return false }
        switch destination {
        case .stock, .waste:
            return false
        case .foundationMinor(let suit):
            guard cards.count == 1, case .minor(let cardSuit, let rank) = first.kind, cardSuit == suit else {
                return false
            }
            if let topCard = minorFoundations[suit]?.last, case .minor(_, let topRank) = topCard.kind {
                return rank.rawValue == topRank.rawValue + 1
            }
            return rank == .ace
        case .foundationMajor:
            guard cards.count == 1, case .major(let arcana) = first.kind else { return false }
            if let topCard = majorFoundation.last, case .major(let topArcana) = topCard.kind {
                return arcana.rawValue == topArcana.rawValue + 1
            }
            return arcana.rawValue == 0
        case .tableau(let col):
            guard let destTop = tableau[col].last else { return true }
            guard case .minor(let destSuit, let destRank) = destTop.kind,
                  case .minor(let cardSuit, let cardRank) = first.kind else { return false }
            return cardSuit.color != destSuit.color && cardRank.rawValue == destRank.rawValue - 1
        }
    }

    // MARK: - Move execution

    @discardableResult
    private func attemptMove(from selection: Selection, to destination: PileLocation) -> Bool {
        guard let cards = peekCards(selection), canPlace(cards: cards, on: destination) else { return false }
        removeCards(selection)
        place(cards: cards, on: destination)
        flipNewTopCard(in: selection.location)
        moveCount += 1
        checkWin()
        return true
    }

    private func peekCards(_ selection: Selection) -> [Card]? {
        switch selection.location {
        case .waste:
            guard let top = waste.last, selection.cardIDs == [top.id] else { return nil }
            return [top]
        case .tableau(let col):
            let cards = tableau[col].filter { selection.cardIDs.contains($0.id) }
            return cards.count == selection.cardIDs.count ? cards : nil
        case .stock, .foundationMinor, .foundationMajor:
            return nil
        }
    }

    private func removeCards(_ selection: Selection) {
        switch selection.location {
        case .waste:
            waste.removeAll { selection.cardIDs.contains($0.id) }
        case .tableau(let col):
            tableau[col].removeAll { selection.cardIDs.contains($0.id) }
        case .stock, .foundationMinor, .foundationMajor:
            break
        }
    }

    private func place(cards: [Card], on destination: PileLocation) {
        switch destination {
        case .foundationMinor(let suit):
            minorFoundations[suit, default: []].append(contentsOf: cards)
        case .foundationMajor:
            majorFoundation.append(contentsOf: cards)
        case .tableau(let col):
            tableau[col].append(contentsOf: cards)
        case .stock, .waste:
            break
        }
    }

    private func flipNewTopCard(in location: PileLocation) {
        guard case .tableau(let col) = location, var top = tableau[col].last, !top.isFaceUp else { return }
        top.isFaceUp = true
        tableau[col][tableau[col].count - 1] = top
    }

    private func checkWin() {
        let minorCount = minorFoundations.values.reduce(0) { $0 + $1.count }
        if minorCount == 56 && majorFoundation.count == 22 {
            isWon = true
        }
    }
}
