import Foundation

/// One row of TrainingLog: a snapshot of the evaluator's weights (see
/// BoardEvaluator) plus whatever outcome stats are available right after a
/// single training run. The running app never reads this back — it exists
/// purely so weight evolution can be correlated with actual self-play
/// success after the fact, from outside the program, instead of only ever
/// seeing the evaluator's current weights and the current session's win
/// rate.
struct TrainingLogEntry: Codable {
    enum Kind: String, Codable {
        case selfPlay
        case puzzles
    }

    let timestamp: Date
    let kind: Kind
    /// Same order as BoardFeatures: [bias, foundationCards, emptyColumns,
    /// reserveOccupied, longestRun, trumpProgress, colourProgress].
    let weights: [Double]
    /// Self-play episodes run this call (.selfPlay), or puzzles trained on
    /// this call (.puzzles).
    let unitsThisRun: Int
    /// Lifetime self-play episode count as of this run.
    let totalEpisodesTrained: Int
    /// Self-play win/loss counts for just this run. Always nil for
    /// .puzzles, which replays known wins rather than playing new games.
    let gamesWonThisRun: Int?
    let gamesPlayedThisRun: Int?
}
