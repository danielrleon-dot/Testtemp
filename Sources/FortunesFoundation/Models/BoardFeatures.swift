import Foundation

/// Hand-crafted summary of a board state, fed to the AI's value function.
/// Kept small and self-contained (it doesn't touch GameState internals)
/// since it's evaluated many times per move during self-play.
enum BoardFeatures {
    static let count = 7

    static func extract(from game: GameState) -> [Double] {
        let foundationCards = Double(game.foundationCardCount)
        let emptyColumns = Double(game.tableau.filter { $0.isEmpty }.count)
        let reserveOccupied: Double = game.reserve == nil ? 0 : 1
        let longestRun = Double(game.tableau.map(chainLength).max() ?? 0)
        let trumpProgress = Double(game.bottomTrump.count + game.topTrump.count)
        let colourProgress = Double(game.colourFoundations.values.reduce(0) { $0 + $1.count })

        return [1.0, foundationCards, emptyColumns, reserveOccupied, longestRun, trumpProgress, colourProgress]
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
