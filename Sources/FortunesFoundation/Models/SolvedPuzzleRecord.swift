import Foundation

/// A puzzle BruteForceSolver has proven winnable, plus the winning move
/// sequence — persisted so SolitaireAI can learn from real, known wins
/// instead of only self-play. `startingSnapshot` (not just `seed`) is the
/// authoritative starting position: the solver can be run from whatever
/// board the player currently has open, not only a freshly dealt one, so
/// replaying purely from the seed wouldn't always reproduce it.
///
/// `rulesVersion` stamps which revision of the gameplay rules (see
/// `GameState.rulesVersion`) this was solved under, so `PuzzleDatabase`
/// can tell a record apart from one solved under rules that have since
/// changed — see that property's doc comment for why that matters.
struct SolvedPuzzleRecord: Codable {
    let seed: UInt64
    let startingSnapshot: GameState.GameSnapshot
    let moves: [Move]
    let rulesVersion: Int

    init(seed: UInt64, startingSnapshot: GameState.GameSnapshot, moves: [Move], rulesVersion: Int = GameState.rulesVersion) {
        self.seed = seed
        self.startingSnapshot = startingSnapshot
        self.moves = moves
        self.rulesVersion = rulesVersion
    }

    /// Records persisted before `rulesVersion` existed have no such field
    /// on disk. They're decoded as version `0`, a value `GameState.
    /// rulesVersion` (starting at 1) never equals, so they're correctly
    /// treated as stale/legacy rather than crashing the whole database
    /// load or silently passing as current-rules puzzles.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seed = try container.decode(UInt64.self, forKey: .seed)
        startingSnapshot = try container.decode(GameState.GameSnapshot.self, forKey: .startingSnapshot)
        moves = try container.decode([Move].self, forKey: .moves)
        rulesVersion = try container.decodeIfPresent(Int.self, forKey: .rulesVersion) ?? 0
    }
}
