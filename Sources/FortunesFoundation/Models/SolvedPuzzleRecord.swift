import Foundation

/// A puzzle BruteForceSolver has proven winnable, plus the winning move
/// sequence — persisted so SolitaireAI can learn from real, known wins
/// instead of only self-play. `startingSnapshot` (not just `seed`) is the
/// authoritative starting position: the solver can be run from whatever
/// board the player currently has open, not only a freshly dealt one, so
/// replaying purely from the seed wouldn't always reproduce it.
struct SolvedPuzzleRecord: Codable {
    let seed: UInt64
    let startingSnapshot: GameState.GameSnapshot
    let moves: [Move]
}
