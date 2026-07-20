import Foundation
import Combine
import SwiftUI

/// Game engine implementing the rules in RULES.md:
/// - 70-card deck (4 colours x 2...King, plus trumps 0...21) dealt into 10 of
///   11 tableau columns (the middle column starts empty), 7 cards each.
/// - Two trump foundations (build up from 0, build down from 21) and four
///   colour foundations (build up from 2), plus a single-card Reserve slot.
/// - Trumps auto-move to their foundation the instant they become apparent,
///   even mid-drag. Colour cards only auto-move once a drag/drop resolves,
///   and never while the Reserve is occupied.
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
    func beginDrag(from location: PileLocation) -> [Card]? {
        guard dragging == nil, let run = draggableRun(from: location) else { return nil }
        switch location {
        case .tableau(let col):
            tableau[col].removeLast(run.count)
        case .reserve:
            reserve = nil
        default:
            return nil
        }
        dragging = DragState(source: location, cards: run)
        runTrumpAutoMoves()
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

    private func draggableRun(from location: PileLocation) -> [Card]? {
        switch location {
        case .reserve:
            guard let card = reserve else { return nil }
            return [card]
        case .tableau(let col):
            var remaining = tableau[col]
            guard let apparent = remaining.popLast() else { return nil }
            var run = [apparent]
            while let candidate = remaining.last,
                  isConsecutivePair(candidate, run.first!),
                  sameDragGroup(candidate, run.first!) {
                run.insert(candidate, at: 0)
                remaining.removeLast()
            }
            return run
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
            tableau[col].append(contentsOf: cards)
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

    /// Trumps only — used while a drag is in progress (mid-drag auto-flight).
    private func runTrumpAutoMoves() {
        var moved = true
        while moved {
            moved = false
            for col in tableau.indices {
                guard let apparent = tableau[col].last, apparent.isTrump,
                      let dest = autoDestination(for: apparent) else { continue }
                tableau[col].removeLast()
                place(cards: [apparent], on: dest)
                moved = true
            }
            if let card = reserve, card.isTrump, let dest = autoDestination(for: card) {
                reserve = nil
                place(cards: [card], on: dest)
                moved = true
            }
        }
    }

    /// Trumps + colours — run after a drop (or after the initial deal).
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
