import Foundation

/// Hand-crafted summary of a board state, fed to the AI's value function.
/// Kept small and self-contained (it doesn't touch GameState internals)
/// since it's evaluated many times per move during self-play.
///
/// Two properties are deliberate after real training data showed the
/// evaluator's weights diverging to ~1e189 over ~6,800 self-play
/// episodes:
///
/// 1. There used to be a `foundationCards` feature too, equal to
///    `trumpProgress + colourProgress` on every single board — an exact
///    linear combination of two other features, not new information.
///    That gave gradient descent a flat direction (shift weight from
///    `foundationCards` onto the other two, or back, without changing any
///    prediction) that ordinary squared-error TD updates don't damp at
///    all, so noise accumulated along it unchecked. Removed rather than
///    just letting BoardEvaluator's weight clamp paper over it.
/// 2. Every feature below is normalized to roughly [0, 1] (the bias stays
///    1.0). Unnormalized counts up to 70 meant every TD update's step
///    size scaled with those large values too, which was the other half
///    of what let the weights run away — normalizing keeps update
///    magnitudes comparable across features regardless of a fixed
///    learning rate.
enum BoardFeatures {
    static let count = 6

    /// 22 trumps (0...21): both the max possible trump-foundation
    /// progress and the longest any same-kind run could ever be (an
    /// all-trump column run).
    private static let maxTrumpCount = 22.0
    /// 4 colours x 12 ranks (2...King, no Aces) each.
    private static let maxColourCards = 48.0

    static func extract(from game: GameState) -> [Double] {
        let emptyColumns = Double(game.tableau.filter { $0.isEmpty }.count) / Double(GameState.columnCount)
        let reserveOccupied: Double = game.reserve == nil ? 0 : 1
        let longestRun = Double(game.tableau.map(chainLength).max() ?? 0) / maxTrumpCount
        let trumpProgress = Double(game.bottomTrump.count + game.topTrump.count) / maxTrumpCount
        let colourProgress = Double(game.colourFoundations.values.reduce(0) { $0 + $1.count }) / maxColourCards

        return [1.0, emptyColumns, reserveOccupied, longestRun, trumpProgress, colourProgress]
    }

    /// Length of the consecutive-rank, same-colour-or-all-trump run ending
    /// at this column's apparent card — how much could move together. Not
    /// private: BruteForceSolver's best-first heuristic reuses this too.
    static func chainLength(in column: [Card]) -> Int {
        guard let apparent = column.last else { return 0 }
        var length = 1
        var current = apparent
        var idx = column.count - 2
        while idx >= 0 {
            let candidate = column[idx]
            guard abs(candidate.rankValue - current.rankValue) == 1, sameGroup(candidate, current) else { break }
            length += 1
            current = candidate
            idx -= 1
        }
        return length
    }

    private static func sameGroup(_ a: Card, _ b: Card) -> Bool {
        switch (a.colour, b.colour) {
        case (.some(let c1), .some(let c2)): return c1 == c2
        case (.none, .none): return true // both trumps
        default: return false
        }
    }
}
