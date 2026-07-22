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
    @Published private(set) var isThinking: Bool = false
    @Published private(set) var totalEpisodesTrained: Int

    private let discount = 0.98
    private let maxStepsPerGame = 400
    private let trainingQueue = DispatchQueue(label: "SolitaireAI.training", qos: .utility)
    private let searchQueue = DispatchQueue(label: "SolitaireAI.search", qos: .userInitiated)
    private let trainingLog = TrainingLog()

    private static let episodesKey = "SolitaireAI.totalEpisodesTrained"

    /// `BoardEvaluator.loadFromDisk()` returns nil both on first launch
    /// ever and whenever BoardFeatures' shape has changed since the saved
    /// weights were written (its own shape-mismatch guard) — either way,
    /// this is a genuinely fresh evaluator that has never seen a single
    /// training update. The lifetime episode counter needs to restart
    /// alongside it: leaving an old, large count in place would push
    /// `explorationRate`/`learningRate` straight to their floors for
    /// weights that know nothing yet, starving them of the exploration
    /// and step size they actually need to (re)learn from scratch.
    init() {
        if let loaded = BoardEvaluator.loadFromDisk() {
            evaluator = loaded
            totalEpisodesTrained = UserDefaults.standard.integer(forKey: Self.episodesKey)
        } else {
            evaluator = BoardEvaluator()
            totalEpisodesTrained = 0
            UserDefaults.standard.set(0, forKey: Self.episodesKey)
        }
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
                let episodeIndex = startingTotal + i
                let exploration = self.explorationRate(afterEpisodes: episodeIndex)
                let stepSize = self.learningRate(afterEpisodes: episodeIndex)
                if self.playOneEpisode(learn: true, explorationRate: exploration, learningRate: stepSize) { won += 1 }
                played += 1
            }
            self.evaluator.saveToDisk()
            let newTotal = startingTotal + played
            UserDefaults.standard.set(newTotal, forKey: Self.episodesKey)
            self.trainingLog.append(TrainingLogEntry(
                timestamp: Date(),
                kind: .selfPlay,
                weights: self.evaluator.weights,
                unitsThisRun: played,
                totalEpisodesTrained: newTotal,
                gamesWonThisRun: won,
                gamesPlayedThisRun: played
            ))
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
        let episodesSnapshot = totalEpisodesTrained
        let stepSize = learningRate(afterEpisodes: episodesSnapshot)
        trainingQueue.async { [weak self] in
            guard let self else { return }
            for record in records {
                self.trainFromSolvedPuzzle(record, learningRate: stepSize)
            }
            self.evaluator.saveToDisk()
            self.trainingLog.append(TrainingLogEntry(
                timestamp: Date(),
                kind: .puzzles,
                weights: self.evaluator.weights,
                unitsThisRun: records.count,
                totalEpisodesTrained: episodesSnapshot,
                gamesWonThisRun: nil,
                gamesPlayedThisRun: nil
            ))
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
    private func trainFromSolvedPuzzle(_ record: SolvedPuzzleRecord, learningRate: Double) {
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

    /// One frontier entry for `suggestMove`'s lookahead search: a candidate
    /// position, the moves that reached it from the current live game, and
    /// how promising the evaluator currently thinks it is (higher is
    /// better — the opposite convention from BruteForceSolver's own
    /// heuristic, matching `BoardEvaluator.value(for:)`).
    private struct SearchNode {
        let snapshot: GameState.GameSnapshot
        let path: [Move]
        let value: Double
    }

    /// Picks the AI's current best move for a live game, with no
    /// training/weight updates, via a small bounded best-first search
    /// guided by the evaluator — not by comparing only the immediate next
    /// board (see `bestMove(_:in:)`, still used by self-play for speed).
    ///
    /// Confirmed experimentally that pure greedy 1-ply comparison is
    /// fundamentally too weak for this game: even scored with a
    /// well-tuned hand-crafted heuristic (not this evaluator, an even
    /// better-established one), a greedy walk won zero of several
    /// known-solvable test deals, and the real trained evaluator showed
    /// the same thing — zero wins across an entire self-play history even
    /// after 145 solved puzzles' worth of supervised training. Greedy
    /// 1-ply has no way to recover from a locally-good-looking move that
    /// dead-ends many moves later; a bounded search can at least route
    /// around some of those traps instead of walking straight into them.
    ///
    /// Runs on a background queue against a scratch copy of `game` —
    /// exactly like BruteForceSolver — so the UI stays responsive despite
    /// taking up to `timeLimit` to respond, and the live game is only
    /// touched once, when `completion` is called with the chosen move.
    /// Falls back to plain greedy comparison in the (practically
    /// never-hit, since `timeLimit` defaults to several seconds) case
    /// where the search doesn't manage to expand even the root's
    /// children before its deadline — this should always produce some
    /// move rather than silently doing nothing.
    func suggestMove(for game: GameState, timeLimit: TimeInterval = 2.0, completion: @escaping (Move?) -> Void) {
        guard !isThinking else { completion(nil); return }
        isThinking = true

        let snapshot = game.currentSnapshot()
        let evaluatorSnapshot = evaluator

        searchQueue.async { [weak self] in
            guard let self else { return }
            let chosenMove = self.searchForMove(from: snapshot, timeLimit: timeLimit, evaluator: evaluatorSnapshot)
            DispatchQueue.main.async {
                self.isThinking = false
                completion(chosenMove)
            }
        }
    }

    private func searchForMove(from snapshot: GameState.GameSnapshot, timeLimit: TimeInterval, evaluator: BoardEvaluator) -> Move? {
        let worker = GameState(seed: 0)
        worker.restore(snapshot)

        let rootMoves = worker.legalMoves()
        guard !rootMoves.isEmpty else { return nil }

        let deadline = Date().addingTimeInterval(timeLimit)
        var visited = Set<String>()
        visited.insert(worker.canonicalStateKey())

        // Ordered so popMin() always returns the *highest*-value node —
        // the opposite of BruteForceSolver's min-first heuristic search,
        // matching "higher evaluator value is more promising."
        var heap = MinHeap<SearchNode> { $0.value > $1.value }
        heap.insert(SearchNode(snapshot: snapshot, path: [], value: evaluator.value(for: BoardFeatures.extract(from: worker))))

        var bestSeen: SearchNode?

        searchLoop: while !heap.isEmpty, Date() < deadline {
            guard let node = heap.popMin() else { break searchLoop }
            worker.restore(node.snapshot)

            if bestSeen == nil || node.value > bestSeen!.value {
                bestSeen = node
            }
            if worker.isWon {
                break searchLoop
            }

            for move in worker.legalMoves() {
                worker.restore(node.snapshot)
                guard worker.performMove(move, recordForUndo: false) else { continue }

                let childPath = node.path + [move]
                if worker.isWon {
                    bestSeen = SearchNode(snapshot: worker.currentSnapshot(), path: childPath, value: .greatestFiniteMagnitude)
                    break searchLoop
                }

                let key = worker.canonicalStateKey()
                if visited.contains(key) { continue }
                visited.insert(key)

                let value = evaluator.value(for: BoardFeatures.extract(from: worker))
                heap.insert(SearchNode(snapshot: worker.currentSnapshot(), path: childPath, value: value))
            }
        }

        if let move = bestSeen?.path.first {
            return move
        }
        // Only reachable with an unreasonably tight timeLimit that didn't
        // leave time to expand even the root's children — fall back to
        // plain greedy rather than returning nothing. worker may have
        // been left at some descendant snapshot by the loop above, so
        // restore it to the root position first.
        worker.restore(snapshot)
        return bestMove(rootMoves, in: worker)
    }

    /// Random-move probability during training, decaying as more games
    /// accumulate (lifetime, not just this run) — early on the AI needs to
    /// explore to find anything that works at all, but a fixed rate would
    /// keep sabotaging otherwise-good, near-complete games forever.
    private func explorationRate(afterEpisodes n: Int) -> Double {
        max(0.02, 0.15 - Double(n) * 0.00005)
    }

    /// TD(0) step size, decaying with lifetime episodes for the same
    /// reason explorationRate does. A permanently fixed step size doesn't
    /// converge under bootstrapping — it settles into a noisy
    /// neighborhood, not a point — which combined with the feature
    /// collinearity BoardFeatures used to have was what let the weights
    /// diverge to ~1e189 in practice over real training.
    private func learningRate(afterEpisodes n: Int) -> Double {
        max(0.001, 0.01 - Double(n) * 0.0000015)
    }

    @discardableResult
    private func playOneEpisode(learn: Bool, explorationRate: Double, learningRate: Double) -> Bool {
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
