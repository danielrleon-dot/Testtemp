import Foundation

/// Bulk-generates a batch of solved puzzles for PuzzleDatabase: deals a
/// fresh random game, attempts to solve it with a bounded per-game time
/// limit, and if it doesn't solve within that budget — whether genuinely
/// proven unsolvable or just timed out — abandons it (no resuming) and
/// moves straight on to a new deal. Stops at whichever comes first: a
/// target number of new puzzles solved, or a total time budget elapsed.
///
/// Complements the interactive single-game Solver rather than replacing
/// it: this is for building up PuzzleDatabase in bulk, unattended, not for
/// solving the one game currently on screen. Owns its own private
/// `BruteForceSolver` instance (via `attemptSolve`, which is otherwise
/// unrelated to that class's interactive pause/resume state) so it never
/// interferes with the player's own in-progress interactive search.
final class PuzzleGenerator: ObservableObject {
    @Published private(set) var isGenerating = false
    @Published private(set) var lastRunSolvedCount = 0
    @Published private(set) var lastRunAttemptedCount = 0

    private let solver = BruteForceSolver()
    private let queue = DispatchQueue(label: "PuzzleGenerator.generate", qos: .userInitiated)

    /// Runs entirely on a background queue. `onSolved` is called once, on
    /// the main thread, when the whole batch finishes (not progressively
    /// per puzzle) — matching the same "one final dispatch" pattern
    /// SolitaireAI's self-play training already uses.
    func generate(
        targetSolvedCount: Int = 10,
        perGameTimeLimit: TimeInterval = 10,
        totalTimeLimit: TimeInterval = 120,
        onSolved: @escaping ([SolvedPuzzleRecord]) -> Void
    ) {
        guard !isGenerating else { return }
        isGenerating = true

        queue.async { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(totalTimeLimit)
            var solvedRecords: [SolvedPuzzleRecord] = []
            var attempted = 0

            while solvedRecords.count < targetSolvedCount, Date() < deadline {
                let seed = UInt64.random(in: UInt64.min...UInt64.max)
                let game = GameState(seed: seed)
                let startingSnapshot = game.currentSnapshot()
                attempted += 1

                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { break }

                if let moves = self.solver.attemptSolve(from: startingSnapshot, timeLimit: min(perGameTimeLimit, remaining)) {
                    solvedRecords.append(SolvedPuzzleRecord(seed: seed, startingSnapshot: startingSnapshot, moves: moves))
                }
            }

            let finalRecords = solvedRecords
            let finalAttempted = attempted
            DispatchQueue.main.async {
                self.lastRunSolvedCount = finalRecords.count
                self.lastRunAttemptedCount = finalAttempted
                self.isGenerating = false
                onSolved(finalRecords)
            }
        }
    }
}
