import Foundation
import Combine
import SwiftUI

/// Game engine implementing the rules in RULES.md:
/// - 70-card deck (4 colours x 2...King, plus trumps 0...21) dealt into 10 of
///   11 tableau columns (the middle column starts empty), 7 cards each.
/// - Two trump foundations (build up from 0, build down from 21) and four
///   colour foundations (build up from 2), plus a single-card Reserve slot.
/// - Trumps and colour cards both only auto-move once a drag/drop resolves
///   (never mid-drag), regardless of where the dragged card lands. Colour
///   auto-moves are additionally suspended while the Reserve is occupied.
final class GameState: ObservableObject {
    @Published var tableau: [[Card]] = []
    @Published var reserve: Card? = nil
    @Published var bottomTrump: [Card] = []
    @Published var topTrump: [Card] = []
    @Published var colourFoundations: [Colour: [Card]] = [:]

    @Published var dragging: DragState? = nil
    @Published var dragPoint: CGPoint? = nil
    @Published var targetFrames: [PileLocation: CGRect] = [:]

    @Published var moveCount: Int = 0
    @Published var isWon: Bool = false

    struct DragState {
        let source: PileLocation
        let cards: [Card]
    }

    static let columnCount = 11
    static let middleColumn = 5

    init() {
        newGame()
    }

    // MARK: - Setup

    func newGame() {
        var deck = Deck.fullShuffledDeck()
        tableau = Array(repeating: [], count: Self.columnCount)
        for col in 0..<Self.columnCount where col != Self.middleColumn {
            for _ in 0..<7 {
                if let card = deck.popLast() {
                    tableau[col].append(card)
                }
            }
        }
        reserve = nil
        bottomTrump = []
        topTrump = []
        colourFoundations = Dictionary(uniqueKeysWithValues: Colour.allCases.map { ($0, []) })
        dragging = nil
        dragPoint = nil
        moveCount = 0
        isWon = false
        runFullAutoMoves()
    }

    // MARK: - Drag lifecycle

    @discardableResult
    func beginDrag(from location: PileLocation, cardID: UUID) -> [Card]? {
        guard dragging == nil, let run = draggableRun(from: location, cardID: cardID) else { return nil }
        switch location {
        case .tableau(let col):
            tableau[col].removeLast(run.count)
        case .reserve:
            reserve = nil
        default:
            return nil
        }
        dragging = DragState(source: location, cards: run)
        return run
    }

    func endDrag(at point: CGPoint) {
        guard let drag = dragging else { return }
        dragging = nil
        dragPoint = nil

        let target = targetFrames.first { $0.value.contains(point) }?.key
        if let target, target != drag.source, canPlace(cards: drag.cards, on: target) {
            place(cards: drag.cards, on: target)
            moveCount += 1
        } else {
            returnCards(drag.cards, to: drag.source)
        }
        runFullAutoMoves()
    }

    private func returnCards(_ cards: [Card], to source: PileLocation) {
        switch source {
        case .tableau(let col):
            tableau[col].append(contentsOf: cards)
        case .reserve:
            reserve = cards.first
        default:
            break
        }
    }

    // MARK: - Drag validation

    /// Which card you grab determines what moves: the apparent (bottom)
    /// card always takes just itself; the card at the top of the matching
    /// run takes the whole run with it; grabbing anything in between (or
    /// an unrelated buried card) isn't a valid grab at all.
    private func draggableRun(from location: PileLocation, cardID: UUID) -> [Card]? {
        switch location {
        case .reserve:
            guard let card = reserve, card.id == cardID else { return nil }
            return [card]
        case .tableau(let col):
            let column = tableau[col]
            guard let apparent = column.last else { return nil }

            var chain = [apparent]
            var idx = column.count - 2
            while idx >= 0, isConsecutivePair(column[idx], chain.first!), sameDragGroup(column[idx], chain.first!) {
                chain.insert(column[idx], at: 0)
                idx -= 1
            }

            if cardID == apparent.id {
                return [apparent]
            } else if cardID == chain.first!.id, chain.count > 1 {
                return chain
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    private func isConsecutivePair(_ a: Card, _ b: Card) -> Bool {
        abs(a.rankValue - b.rankValue) == 1
    }

    private func sameDragGroup(_ a: Card, _ b: Card) -> Bool {
        switch (a.kind, b.kind) {
        case (.colour(let c1, _), .colour(let c2, _)):
            return c1 == c2
        case (.trump, .trump):
            return true
        default:
            return false
        }
    }

    private func canPlace(cards: [Card], on destination: PileLocation) -> Bool {
        guard let leading = cards.last else { return false }
        switch destination {
        case .reserve:
            return cards.count == 1 && reserve == nil
        case .bottomTrump:
            guard cards.count == 1, case .trump(let n) = leading.kind else { return false }
            if let top = bottomTrump.last, case .trump(let topN) = top.kind {
                return n == topN + 1
            }
            return n == 0
        case .topTrump:
            guard cards.count == 1, case .trump(let n) = leading.kind else { return false }
            if let top = topTrump.last, case .trump(let topN) = top.kind {
                return n == topN - 1
            }
            return n == 21
        case .colourFoundation(let colour):
            guard cards.count == 1, case .colour(let cardColour, let rank) = leading.kind, cardColour == colour else {
                return false
            }
            if let top = colourFoundations[colour]?.last, case .colour(_, let topRank) = top.kind {
                return rank.rawValue == topRank.rawValue + 1
            }
            return rank == .two
        case .tableau(let col):
            guard let top = tableau[col].last else { return true }
            return isConsecutivePair(top, leading) && sameDragGroup(top, leading)
        }
    }

    // MARK: - Placement

    private func place(cards: [Card], on destination: PileLocation) {
        switch destination {
        case .reserve:
            reserve = cards.first
        case .bottomTrump:
            bottomTrump.append(contentsOf: cards)
        case .topTrump:
            topTrump.append(contentsOf: cards)
        case .colourFoundation(let colour):
            colourFoundations[colour, default: []].append(contentsOf: cards)
        case .tableau(let col):
            // Dragging a multi-card run is shorthand for moving each card
            // one at a time, starting from the apparent (grabbed) card —
            // it's not a distinct move of its own. So the apparent card
            // (cards.last) lands first/deepest, and the run's far end
            // (cards.first) ends up as the new apparent card on top.
            // A single-card "run" is unaffected: reversing one element is a no-op.
            tableau[col].append(contentsOf: cards.reversed())
        }
    }

    // MARK: - Automatic moves

    private func autoDestination(for card: Card) -> PileLocation? {
        switch card.kind {
        case .trump(let n):
            if n == 0 { return .bottomTrump }
            if n == 21 { return .topTrump }
            if let top = bottomTrump.last, case .trump(let topN) = top.kind, n == topN + 1 {
                return .bottomTrump
            }
            if let top = topTrump.last, case .trump(let topN) = top.kind, n == topN - 1 {
                return .topTrump
            }
            return nil
        case .colour(let colour, let rank):
            guard reserve == nil else { return nil }
            if rank == .two { return .colourFoundation(colour) }
            if let top = colourFoundations[colour]?.last, case .colour(_, let topRank) = top.kind,
               rank.rawValue == topRank.rawValue + 1 {
                return .colourFoundation(colour)
            }
            return nil
        }
    }

    /// Trumps + colours — run after a drop resolves, no matter where the
    /// dragged card landed (a column, the Reserve, or a foundation slot),
    /// or after the initial deal. Never runs while a drag is in progress.
    private func runFullAutoMoves() {
        var moved = true
        while moved {
            moved = false
            for col in tableau.indices {
                guard let apparent = tableau[col].last, let dest = autoDestination(for: apparent) else { continue }
                tableau[col].removeLast()
                place(cards: [apparent], on: dest)
                moved = true
            }
            if let card = reserve, let dest = autoDestination(for: card) {
                reserve = nil
                place(cards: [card], on: dest)
                moved = true
            }
        }
        checkWin()
    }

    private func checkWin() {
        let total = bottomTrump.count + topTrump.count + colourFoundations.values.reduce(0) { $0 + $1.count }
        if total == 70 {
            isWon = true
        }
    }
}
