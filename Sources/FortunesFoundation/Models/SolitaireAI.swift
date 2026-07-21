import Foundation

/// Trains a BoardEvaluator via TD(0) self-play. This solitaire has no
/// opponent and no hidden information (every card is visible once dealt),
/// so "learning" here means: play many games against itself, and after
/// every move nudge the value function toward better predicting how
/// promising the resulting board is. Training runs on a background queue
/// against disposable GameState instances it creates itself — it never
/// touches whatever game the player currently has open. Learned weights,
/// and the lifetime training count, persist across launches via
/// UserDefaults.
final class SolitaireAI: ObservableObject {
    private var evaluator: BoardEvaluator
    @Published private(set) var gamesPlayed: Int = 0
    @Published private(set) var gamesWon: Int = 0
    @Published private(set) var isTraining: Bool = false
    @Published private(set) var totalEpisodesTrained: Int

    private let learningRate = 0.01
    private let discount = 0.98
    private let maxStepsPerGame = 400
    private let trainingQueue = DispatchQueue(label: "SolitaireAI.training", qos: .utility)

    private static let episodesKey = "SolitaireAI.totalEpisodesTrained"

    init() {
        evaluator = BoardEvaluator.loadFromDisk() ?? BoardEvaluator()
        totalEpisodesTrained = UserDefaults.standard.integer(forKey: Self.episodesKey)
    }

    /// Runs `episodes` self-play games on a background queue, updating the
    /// evaluator's weights after every move, then saves the result. Safe
    /// to call again once a previous run finishes; ignored while training.
    func train(episodes: Int) {
        guard !isTraining else { return }
        isTraining = true
        let startingTotal = totalEpisodesTrained
        trainingQueue.async { [weak self] in
            guard let self else { return }
            var played = 0
            var won = 0
            for i in 0..<episodes {
                let rate = self.explorationRate(afterEpisodes: startingTotal + i)
                if self.playOneEpisode(learn: true, explorationRate: rate) { won += 1 }
                played += 1
            }
            self.evaluator.saveToDisk()
            let newTotal = startingTotal + played
            UserDefaults.standard.set(newTotal, forKey: Self.episodesKey)
            DispatchQueue.main.async {
                self.gamesPlayed += played
                self.gamesWon += won
                self.totalEpisodesTrained = newTotal
                self.isTraining = false
            }
        }
    }

    /// Supervised training from puzzles BruteForceSolver has actually
    /// proven winnable (see SolvedPuzzleRecord/PuzzleDatabase) — a
    /// stronger, more direct signal than self-play, since every state
    /// along the path is known to lead to a real win rather than an
    /// estimate. Complements self-play; doesn't replace it, and shares
    /// its `isTraining` guard so the two never run — and mutate
    /// `evaluator` — concurrently.
    func trainFromSolvedPuzzles(_ records: [SolvedPuzzleRecord]) {
        guard !isTraining, !records.isEmpty else { return }
        isTraining = true
        trainingQueue.async { [weak self] in
            guard let self else { return }
            for record in records {
                self.trainFromSolvedPuzzle(record)
            }
            self.evaluator.saveToDisk()
            DispatchQueue.main.async {
                self.isTraining = false
            }
        }
    }

    /// Replays a known winning trajectory and trains toward it backward
    /// from the win, so each step's bootstrap is an exact computed return
    /// rather than a self-play estimate that needs several passes to
    /// settle — the same reward/discount shape as self-play, just applied
    /// to a path that's known in full instead of built move by move.
    private func trainFromSolvedPuzzle(_ record: SolvedPuzzleRecord) {
        let game = GameState(seed: record.seed)
        game.restore(record.startingSnapshot)

        var featuresAlongPath: [[Double]] = [BoardFeatures.extract(from: game)]
        var foundationCounts: [Int] = [game.foundationCardCount]

        for move in record.moves {
            guard game.performMove(move, recordForUndo: false) else { break }
            featuresAlongPath.append(BoardFeatures.extract(from: game))
            foundationCounts.append(game.foundationCardCount)
        }
        guard featuresAlongPath.count >= 2 else { return }

        var target = 50.0 // value of the final (won) state, matching self-play's win bootstrap
        var i = featuresAlongPath.count - 2
        while i >= 0 {
            let reward = Double(foundationCounts[i + 1] - foundationCounts[i]) - 0.02
            let stepTarget = reward + discount * target
            evaluator.update(features: featuresAlongPath[i], targetValue: stepTarget, learningRate: learningRate)
            target = stepTarget
            i -= 1
        }
    }

    /// Picks the AI's current best move for a live game, with no
    /// training/weight updates. Returns nil if the board has no legal
    /// move at all (a dead end). Runs synchronously on the calling
    /// (expected: main) thread — it briefly mutates and rolls back the
    /// passed-in game once per candidate move to score it.
    func suggestMove(for game: GameState) -> Move? {
        let moves = game.legalMoves()
        guard !moves.isEmpty else { return nil }
        return bestMove(moves, in: game)
    }

    /// Random-move probability during training, decaying as more games
    /// accumulate (lifetime, not just this run) — early on the AI needs to
    /// explore to find anything that works at all, but a fixed rate would
    /// keep sabotaging otherwise-good, near-complete games forever.
    private func explorationRate(afterEpisodes n: Int) -> Double {
        max(0.02, 0.15 - Double(n) * 0.00005)
    }

    @discardableResult
    private func playOneEpisode(learn: Bool, explorationRate: Double) -> Bool {
        let game = GameState(seed: UInt64.random(in: UInt64.min...UInt64.max))
        var previousFeatures = BoardFeatures.extract(from: game)
        var steps = 0

        while steps < maxStepsPerGame, !game.isWon {
            let moves = game.legalMoves()
            guard !moves.isEmpty else { break }

            let move: Move
            if learn, Double.random(in: 0...1) < explorationRate {
                move = moves.randomElement()!
            } else {
                move = bestMove(moves, in: game)
            }

            let before = game.foundationCardCount
            game.performMove(move, recordForUndo: false)
            let after = game.foundationCardCount
            // Small per-move cost keeps the AI from stalling in place;
            // moving a card to a foundation is the main positive signal.
            let reward = Double(after - before) - 0.02

            let newFeatures = BoardFeatures.extract(from: game)
            if learn {
                let bootstrap = game.isWon ? 50.0 : evaluator.value(for: newFeatures)
                evaluator.update(features: previousFeatures, targetValue: reward + discount * bootstrap, learningRate: learningRate)
            }
            previousFeatures = newFeatures
            steps += 1
        }
        return game.isWon
    }

    /// Scores every candidate by actually applying it to `game`, reading
    /// the resulting value, then rolling back via snapshot/restore — so
    /// none of the trial moves are left in place.
    private func bestMove(_ moves: [Move], in game: GameState) -> Move {
        var best = moves[0]
        var bestValue = -Double.infinity
        for move in moves {
            let snapshot = game.currentSnapshot()
            game.performMove(move, recordForUndo: false)
            let value = game.isWon ? 1000.0 : evaluator.value(for: BoardFeatures.extract(from: game))
            game.restore(snapshot)
            if value > bestValue {
                bestValue = value
                best = move
            }
        }
        return best
    }
}
