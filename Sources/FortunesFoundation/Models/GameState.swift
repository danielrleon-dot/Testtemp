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

    /// The seed the current deal was shuffled from. Displayed to the
    /// player so they can note it down and replay the same deal later via
    /// newGame(seed:).
    @Published private(set) var currentSeed: UInt64 = 0

    /// Player-facing option: when true, dropping the dragged card onto a
    /// tableau column also pulls along the rest of the matching run behind
    /// it (inverted); when false, dragging always moves that one card
    /// alone. Not reset by newGame() — it's a play-style preference.
    @Published var moveWholeColumn: Bool = false

    @Published private var undoStack: [GameSnapshot] = []
    @Published private var redoStack: [GameSnapshot] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    struct DragState {
        let source: PileLocation
        let cards: [Card]
    }

    /// A full copy of everything undo/redo needs to restore. moveCount is
    /// included so it rewinds/replays in lockstep with the board. Not
    /// private: SolitaireAI also uses this to simulate-and-roll-back
    /// candidate moves when picking the best one. Codable so a solved
    /// puzzle's starting position can be persisted (see
    /// SolvedPuzzleRecord) and replayed later for supervised training.
    struct GameSnapshot: Codable {
        let tableau: [[Card]]
        let reserve: Card?
        let bottomTrump: [Card]
        let topTrump: [Card]
        let colourFoundations: [Colour: [Card]]
        let moveCount: Int
    }

    static let columnCount = 11
    static let middleColumn = 5

    /// Identifies which revision of the gameplay rules (RULES.md, and this
    /// file's implementation of it) a `SolvedPuzzleRecord` was solved
    /// under. Bump this by hand any time a change here changes what's
    /// legal or how the board behaves — auto-move conditions, placement
    /// legality, board shape (column count, foundation types), the
    /// "drag whole column" behaviour, etc. — the same "edit both by hand,
    /// nothing enforces it" honor system CLAUDE.md already asks for
    /// between RULES.md and this file, just extended to a version number
    /// puzzles get stamped with. `PuzzleDatabase` uses a mismatch against
    /// this value to treat a record as stale: after a rules change, an
    /// older record's stored moves may no longer even be legal, and even
    /// if they happen to still replay, they no longer reflect the game as
    /// it's actually played, so they'd be actively harmful to train the AI
    /// on. Cosmetic-only changes (view/rendering code, UI copy) don't need
    /// a bump.
    static let rulesVersion = 1

    /// Pass a seed to deal directly to a reproducible game (e.g. for AI
    /// self-play); omit it for a fresh random deal.
    init(seed: UInt64? = nil) {
        newGame(seed: seed)
    }

    // MARK: - Setup

    /// Starts a new deal. Pass a seed to reproduce a specific deal later;
    /// omit it for a fresh random one. The seed used is always published
    /// via `currentSeed` so the player can note it down either way.
    func newGame(seed: UInt64? = nil) {
        let usedSeed = seed ?? UInt64.random(in: UInt64.min...UInt64.max)
        currentSeed = usedSeed
        var deck = Deck.fullShuffledDeck(seed: usedSeed)
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
        undoStack = []
        redoStack = []
        runFullAutoMoves()
    }

    // MARK: - Undo / redo

    func currentSnapshot() -> GameSnapshot {
        GameSnapshot(
            tableau: tableau,
            reserve: reserve,
            bottomTrump: bottomTrump,
            topTrump: topTrump,
            colourFoundations: colourFoundations,
            moveCount: moveCount
        )
    }

    func restore(_ snapshot: GameSnapshot) {
        tableau = snapshot.tableau
        reserve = snapshot.reserve
        bottomTrump = snapshot.bottomTrump
        topTrump = snapshot.topTrump
        colourFoundations = snapshot.colourFoundations
        moveCount = snapshot.moveCount
        checkWin()
    }

    /// Undoes the last completed move (a manual placement plus whatever
    /// auto-moves followed from it, as one unit). Can be pressed
    /// repeatedly to step back through the whole game. Ignored mid-drag.
    func undo() {
        guard dragging == nil, let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        restore(previous)
    }

    /// Re-applies a move previously undone. Ignored mid-drag, or once
    /// there's nothing left to redo (including after any new move, which
    /// clears the redo history).
    func redo() {
        guard dragging == nil, let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        restore(next)
    }

    // MARK: - Drag lifecycle

    /// Only the apparent (bottom) card of a column, or the Reserve's card,
    /// can ever be grabbed — dragging always lifts just that one card.
    ///
    /// Note: the card is *not* removed from its pile here. Removing it
    /// immediately used to make SwiftUI tear down and rebuild the very
    /// view whose gesture was mid-drag (its identity vanished from the
    /// ForEach the instant the array changed), which killed the gesture
    /// and dropped the card. Leaving the source untouched until the drop
    /// actually resolves keeps that view — and its gesture — alive for
    /// the whole gesture. The view layer hides the card in place (opacity
    /// 0) while it's being dragged, so it doesn't appear twice.
    @discardableResult
    func beginDrag(from location: PileLocation, cardID: UUID) -> [Card]? {
        guard dragging == nil else { return nil }
        switch location {
        case .tableau(let col):
            guard let apparent = tableau[col].last, apparent.id == cardID else { return nil }
            dragging = DragState(source: location, cards: [apparent])
            return [apparent]
        case .reserve:
            guard let card = reserve, card.id == cardID else { return nil }
            dragging = DragState(source: location, cards: [card])
            return [card]
        default:
            return nil
        }
    }

    func endDrag(at point: CGPoint) {
        guard let drag = dragging else { return }
        dragging = nil
        dragPoint = nil

        let target = targetFrames.first { $0.value.contains(point) }?.key
        if let target, target != drag.source, canPlace(cards: drag.cards, on: target) {
            undoStack.append(currentSnapshot())
            redoStack.removeAll()
            let group = fullPlacementGroup(for: drag, droppingOn: target)
            removeFromSource(group, source: drag.source)
            place(cards: group, on: target)
            moveCount += 1
        }
        // Invalid drop (or no target at all): nothing to undo — the card
        // never actually left its pile, so it's already back where it was.
        runFullAutoMoves()
    }

    /// Dropping the dragged card onto the Reserve always sends it there
    /// alone. Dropping it onto a tableau column (empty, or landing on a
    /// matching card) pulls along whatever's left of the same-colour/
    /// trump run still sitting in the source column behind it — but only
    /// if the player has "drag whole column" enabled. The source column
    /// hasn't been touched yet, so this reads its current, untouched state.
    private func fullPlacementGroup(for drag: DragState, droppingOn target: PileLocation) -> [Card] {
        placementGroup(cards: drag.cards, from: drag.source, takeWholeRun: moveWholeColumn, to: target)
    }

    /// Shared by human drags (gated by moveWholeColumn) and AI moves
    /// (which decide per-move via Move.takeWholeRun): the run of
    /// consecutive-rank, same-colour-or-all-trump cards immediately behind
    /// `apparent` in `column`, read without mutating anything.
    private func matchingChain(endingAt apparent: Card, in column: [Card]) -> [Card] {
        var chain = [apparent]
        var idx = column.count - 2
        while idx >= 0, isConsecutivePair(column[idx], chain.first!), sameDragGroup(column[idx], chain.first!) {
            chain.insert(column[idx], at: 0)
            idx -= 1
        }
        return chain
    }

    private func placementGroup(cards: [Card], from source: PileLocation, takeWholeRun: Bool, to destination: PileLocation) -> [Card] {
        guard takeWholeRun, case .tableau(let col) = source, case .tableau = destination,
              let apparent = tableau[col].last, apparent.id == cards[0].id else {
            return cards
        }
        return matchingChain(endingAt: apparent, in: tableau[col])
    }

    private func removeFromSource(_ cards: [Card], source: PileLocation) {
        switch source {
        case .tableau(let col):
            tableau[col].removeLast(cards.count)
        case .reserve:
            reserve = nil
        default:
            break
        }
    }

    // MARK: - Headless moves (for AI self-play / auto-play)

    private func candidateCards(for source: PileLocation) -> [Card]? {
        switch source {
        case .tableau(let col):
            return tableau[col].last.map { [$0] }
        case .reserve:
            return reserve.map { [$0] }
        default:
            return nil
        }
    }

    /// Every currently legal move: from each column's apparent card (or
    /// the Reserve's card) to every destination it could validly land on.
    /// Where a matching run sits behind the apparent card, both taking
    /// just that card and taking the whole run are offered as separate
    /// candidates. Doesn't touch game state — safe to call freely.
    func legalMoves() -> [Move] {
        var sources: [PileLocation] = tableau.indices.compactMap { tableau[$0].isEmpty ? nil : .tableau($0) }
        if reserve != nil { sources.append(.reserve) }

        var destinations: [PileLocation] = [.reserve, .bottomTrump, .topTrump]
        destinations.append(contentsOf: Colour.allCases.map { .colourFoundation($0) })
        destinations.append(contentsOf: (0..<Self.columnCount).map { .tableau($0) })

        var moves: [Move] = []
        for source in sources {
            guard let cards = candidateCards(for: source) else { continue }
            for destination in destinations where destination != source {
                guard canPlace(cards: cards, on: destination) else { continue }
                moves.append(Move(source: source, destination: destination, takeWholeRun: false))
                if case .tableau(let col) = source, case .tableau = destination {
                    let chain = matchingChain(endingAt: cards[0], in: tableau[col])
                    if chain.count > 1 {
                        moves.append(Move(source: source, destination: destination, takeWholeRun: true))
                    }
                }
            }
        }
        return moves
    }

    /// Applies a move produced by legalMoves() without any gesture/drag
    /// machinery. `recordForUndo` should be true for a move made in a
    /// live, player-visible game (so Undo still works afterward), and
    /// false for disposable AI self-play instances. Returns false (and
    /// does nothing) if the move is no longer legal.
    @discardableResult
    func performMove(_ move: Move, recordForUndo: Bool) -> Bool {
        guard let cards = candidateCards(for: move.source), move.destination != move.source,
              canPlace(cards: cards, on: move.destination) else {
            return false
        }
        if recordForUndo {
            undoStack.append(currentSnapshot())
            redoStack.removeAll()
        }
        let group = placementGroup(cards: cards, from: move.source, takeWholeRun: move.takeWholeRun, to: move.destination)
        removeFromSource(group, source: move.source)
        place(cards: group, on: move.destination)
        moveCount += 1
        runFullAutoMoves()
        return true
    }

    var foundationCardCount: Int {
        bottomTrump.count + topTrump.count + colourFoundations.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Drag validation

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
        isWon = foundationCardCount == 70
    }

    // MARK: - Search support

    /// Canonical string encoding of this board's full state, for
    /// deduplicating already-explored positions during search. Shared by
    /// `BruteForceSolver` and `SolitaireAI`'s search-guided move
    /// selection, rather than each maintaining its own copy — this exact
    /// logic has already needed one subtle correctness fix (see below),
    /// and a second, drifted copy would risk quietly reintroducing it.
    ///
    /// Tableau columns are encoded and then **sorted** before joining —
    /// deliberately throwing away which physical column index holds which
    /// stack. Column index never affects legality (`canPlace`/`legalMoves`
    /// only ever look at a column's *contents*, never its index), so two
    /// boards that differ only by, say, which of several empty columns a
    /// lone parked card sits in are the exact same position for every
    /// purpose that matters to a search. Treating every such relabeling as
    /// a brand-new, never-before-seen state was confirmed experimentally
    /// (an independent Python reimplementation, same 40 test deals) to
    /// inflate exploration dramatically: solve rate 10.0% -> 37.5%, average
    /// states needed to find a win 74,995 -> 11,218, timeouts 35.0% ->
    /// 5.0%. Reserve/bottomTrump/topTrump/colourFoundations are each a
    /// unique, non-interchangeable slot, so only the tableau columns are
    /// canonicalized this way — everything else keeps its fixed position.
    func canonicalStateKey() -> String {
        var columnParts = tableau.map { $0.map(Self.cardCode).joined(separator: ",") }
        columnParts.sort()

        var parts: [String] = columnParts
        parts.append(reserve.map(Self.cardCode) ?? "-")
        parts.append(bottomTrump.map(Self.cardCode).joined(separator: ","))
        parts.append(topTrump.map(Self.cardCode).joined(separator: ","))
        for colour in Colour.allCases {
            parts.append((colourFoundations[colour] ?? []).map(Self.cardCode).joined(separator: ","))
        }
        return parts.joined(separator: "|")
    }

    /// Each of the 70 cards has a unique colour/rank-or-trump-number
    /// combination in this deck, so that alone is enough to identify one.
    private static func cardCode(_ card: Card) -> String {
        switch card.kind {
        case .colour(let colour, let rank): return "\(colour.rawValue)\(rank.rawValue)"
        case .trump(let n): return "T\(n)"
        }
    }
}
