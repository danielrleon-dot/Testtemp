import Foundation

/// Exhaustive depth-first search for a winning move sequence from a given
/// board — no learning, no evaluation function, just try a move, recurse,
/// backtrack if it leads nowhere. The only thing pruning it beyond pure
/// brute force is skipping board states already proven fruitless earlier
/// in the same search (a state that leads nowhere once leads nowhere any
/// other time it's reached), which doesn't skip any reachable win.
///
/// This game's search space is astronomically large, so genuinely
/// exhaustive completion isn't realistic for most positions within any
/// human-scale time budget. A hard wall-clock time limit is required —
/// hitting it means "inconclusive," not "unsolvable." Separate from
/// SolitaireAI on purpose: this is a different kind of tool (exact search
/// vs. a learned approximation), not a competing implementation of it.
final class BruteForceSolver: ObservableObject {
    enum Status: Equatable {
        case idle
        case searching
        case solved(moveCount: Int)
        case noSolutionFound(statesExplored: Int)
        case timedOut(statesExplored: Int)
        case cancelled(statesExplored: Int)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var statesExplored: Int = 0
    @Published private(set) var elapsedSeconds: Double = 0

    private(set) var solution: [Move] = []
    @Published private(set) var solutionStepsPlayed: Int = 0

    private let searchQueue = DispatchQueue(label: "BruteForceSolver.search", qos: .userInitiated)
    private var progress: SearchProgress?
    private var progressTimer: Timer?

    /// Thread-safe (lock-backed) counter + cancel flag: the search loop on
    /// the background queue writes to it continuously; the main-thread
    /// progress timer and the Stop button read/set it concurrently.
    private final class SearchProgress {
        private let lock = NSLock()
        private var explored = 0
        private var cancelled = false

        func incrementExplored() {
            lock.lock(); explored += 1; lock.unlock()
        }
        func requestCancel() {
            lock.lock(); cancelled = true; lock.unlock()
        }
        var statesExplored: Int {
            lock.lock(); defer { lock.unlock() }; return explored
        }
        var isCancelled: Bool {
            lock.lock(); defer { lock.unlock() }; return cancelled
        }
    }

    /// Starts an exhaustive search from `game`'s current position. Runs on
    /// a background queue against its own scratch GameState — `game`
    /// itself is only read once (via a snapshot) and never touched again.
    func solve(from game: GameState, timeLimit: TimeInterval) {
        guard status != .searching else { return }
        status = .searching
        statesExplored = 0
        elapsedSeconds = 0
        solution = []
        solutionStepsPlayed = 0

        let snapshot = game.currentSnapshot()
        let progress = SearchProgress()
        self.progress = progress

        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(timeLimit)

        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statesExplored = progress.statesExplored
            self.elapsedSeconds = Date().timeIntervalSince(startedAt)
        }

        searchQueue.async { [weak self] in
            guard let self else { return }
            let worker = GameState(seed: 0)
            worker.restore(snapshot)

            var visited = Set<String>()
            var path: [Move] = []

            func search(_ state: GameState) -> Bool {
                if progress.isCancelled || Date() >= deadline { return false }
                if state.isWon { return true }

                let key = self.stateKey(for: state)
                if visited.contains(key) { return false }
                visited.insert(key)
                progress.incrementExplored()

                for move in state.legalMoves() {
                    let stepSnapshot = state.currentSnapshot()
                    state.performMove(move, recordForUndo: false)
                    path.append(move)

                    if search(state) { return true }

                    path.removeLast()
                    state.restore(stepSnapshot)

                    if progress.isCancelled || Date() >= deadline { return false }
                }
                return false
            }

            let found = search(worker)
            let exploredCount = progress.statesExplored
            let wasCancelled = progress.isCancelled
            let timedOut = Date() >= deadline

            DispatchQueue.main.async {
                self.progressTimer?.invalidate()
                self.statesExplored = exploredCount
                self.elapsedSeconds = Date().timeIntervalSince(startedAt)
                if found {
                    self.solution = path
                    self.status = .solved(moveCount: path.count)
                } else if wasCancelled {
                    self.status = .cancelled(statesExplored: exploredCount)
                } else if timedOut {
                    self.status = .timedOut(statesExplored: exploredCount)
                } else {
                    self.status = .noSolutionFound(statesExplored: exploredCount)
                }
            }
        }
    }

    /// Stops an in-progress search early. The result becomes `.cancelled`
    /// once the current in-flight recursive call notices and unwinds.
    func cancel() {
        progress?.requestCancel()
    }

    /// Applies the next move of a found solution to a live game (through
    /// the normal undo-tracked path), one step at a time so the player can
    /// watch it play out. Returns false once the solution is exhausted.
    @discardableResult
    func playNextSolutionMove(in game: GameState) -> Bool {
        guard solutionStepsPlayed < solution.count else { return false }
        let move = solution[solutionStepsPlayed]
        guard game.performMove(move, recordForUndo: true) else { return false }
        solutionStepsPlayed += 1
        return true
    }

    var hasMoreSolutionSteps: Bool {
        solutionStepsPlayed < solution.count
    }

    /// Canonical string encoding of a board's full state (every pile, in
    /// order — order matters, since it determines what's legal next) for
    /// deduplicating already-explored positions. Each of the 70 cards has
    /// a unique colour/rank-or-trump-number combination in this deck, so
    /// that alone is enough to identify a card.
    private func stateKey(for game: GameState) -> String {
        var parts: [String] = []
        for column in game.tableau {
            parts.append(column.map(cardCode).joined(separator: ","))
        }
        parts.append(game.reserve.map(cardCode) ?? "-")
        parts.append(game.bottomTrump.map(cardCode).joined(separator: ","))
        parts.append(game.topTrump.map(cardCode).joined(separator: ","))
        for colour in Colour.allCases {
            parts.append((game.colourFoundations[colour] ?? []).map(cardCode).joined(separator: ","))
        }
        return parts.joined(separator: "|")
    }

    private func cardCode(_ card: Card) -> String {
        switch card.kind {
        case .colour(let colour, let rank): return "\(colour.rawValue)\(rank.rawValue)"
        case .trump(let n): return "T\(n)"
        }
    }
}
