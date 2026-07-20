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
/// hitting it **pauses** the search rather than abandoning it: all
/// explored states and search progress are kept, and `continueSearching`
/// resumes exactly where it left off with a fresh time budget. Only an
/// explicit `cancel()` (or starting a new search) discards it. Separate
/// from SolitaireAI on purpose: this is a different kind of tool (exact
/// search vs. a learned approximation), not a competing implementation.
///
/// The search is iterative (an explicit heap-allocated stack), not
/// recursive: background DispatchQueue worker threads get a much smaller
/// default stack than the main thread, and a hard-to-solve board can
/// easily need thousands of moves of depth before backtracking — a
/// straightforward recursive version overflowed that stack in practice.
final class BruteForceSolver: ObservableObject {
    enum Status: Equatable {
        case idle
        case searching
        case solved(moveCount: Int)
        case noSolutionFound(statesExplored: Int)
        case paused(statesExplored: Int)
        case cancelled(statesExplored: Int)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var statesExplored: Int = 0
    @Published private(set) var elapsedSeconds: Double = 0

    private(set) var solution: [Move] = []
    @Published private(set) var solutionStepsPlayed: Int = 0

    private let searchQueue = DispatchQueue(label: "BruteForceSolver.search", qos: .userInitiated)
    private var progress: SearchProgress?
    private var session: SearchSession?
    private var progressTimer: Timer?
    private var cumulativeElapsedSeconds: TimeInterval = 0

    /// Thread-safe (lock-backed) counter + cancel flag: the search loop on
    /// the background queue writes to it continuously; the main-thread
    /// progress timer and the Stop button read/set it concurrently. Kept
    /// alive (not recreated) across a pause/continue cycle so the explored
    /// count keeps accumulating instead of resetting.
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

    /// One level of the explicit search stack: the board state at this
    /// level, and the moves from it still left to try.
    private struct Frame {
        let snapshot: GameState.GameSnapshot
        var remainingMoves: [Move]
    }

    /// Everything a search needs to resume exactly where it paused. A
    /// class (not a struct) so the background queue can mutate it in
    /// place across the lifetime of one solve()...continueSearching()...
    /// chain without it needing to flow back out through return values.
    private final class SearchSession {
        let worker: GameState
        var visited: Set<String>
        var stack: [Frame]
        var path: [Move]

        init(worker: GameState, visited: Set<String>, stack: [Frame], path: [Move]) {
            self.worker = worker
            self.visited = visited
            self.stack = stack
            self.path = path
        }
    }

    private enum SearchOutcome {
        case solved(path: [Move])
        case exhausted
        case pausedAtDeadline
        case cancelled
    }

    /// Starts a brand-new exhaustive search from `game`'s current
    /// position, discarding any previously paused search. Runs on a
    /// background queue against its own scratch GameState — `game` itself
    /// is only read once (via a snapshot) and never touched again.
    func solve(from game: GameState, timeLimit: TimeInterval) {
        guard status != .searching else { return }

        let snapshot = game.currentSnapshot()
        let worker = GameState(seed: 0)
        worker.restore(snapshot)

        solution = []
        solutionStepsPlayed = 0
        cumulativeElapsedSeconds = 0
        statesExplored = 0
        elapsedSeconds = 0

        if worker.isWon {
            status = .solved(moveCount: 0)
            return
        }

        let newProgress = SearchProgress()
        var visited = Set<String>()
        visited.insert(stateKey(for: worker))
        newProgress.incrementExplored()
        let initialFrame = Frame(snapshot: worker.currentSnapshot(), remainingMoves: worker.legalMoves())

        progress = newProgress
        session = SearchSession(worker: worker, visited: visited, stack: [initialFrame], path: [])

        runCurrentSearch(timeLimit: timeLimit)
    }

    /// Resumes a search that paused after hitting its time limit, with a
    /// fresh time budget. Does nothing if there's no paused search to
    /// resume (e.g. it was cancelled, solved, or already exhausted).
    func continueSearching(timeLimit: TimeInterval) {
        guard case .paused = status, session != nil, progress != nil else { return }
        runCurrentSearch(timeLimit: timeLimit)
    }

    private func runCurrentSearch(timeLimit: TimeInterval) {
        guard let session, let progress else { return }
        status = .searching

        let runStartedAt = Date()
        let deadline = runStartedAt.addingTimeInterval(timeLimit)
        let baseElapsed = cumulativeElapsedSeconds

        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statesExplored = progress.statesExplored
            self.elapsedSeconds = baseElapsed + Date().timeIntervalSince(runStartedAt)
        }

        searchQueue.async { [weak self] in
            guard let self else { return }
            let outcome = self.runIterativeSearch(session: session, progress: progress, deadline: deadline)
            let exploredCount = progress.statesExplored
            let totalElapsed = baseElapsed + Date().timeIntervalSince(runStartedAt)

            DispatchQueue.main.async {
                self.progressTimer?.invalidate()
                self.cumulativeElapsedSeconds = totalElapsed
                self.statesExplored = exploredCount
                self.elapsedSeconds = totalElapsed

                switch outcome {
                case .solved(let path):
                    self.solution = path
                    self.status = .solved(moveCount: path.count)
                    self.session = nil
                    self.progress = nil
                case .exhausted:
                    self.status = .noSolutionFound(statesExplored: exploredCount)
                    self.session = nil
                    self.progress = nil
                case .pausedAtDeadline:
                    self.status = .paused(statesExplored: exploredCount)
                    // session/progress deliberately kept for continueSearching().
                case .cancelled:
                    self.status = .cancelled(statesExplored: exploredCount)
                    self.session = nil
                    self.progress = nil
                }
            }
        }
    }

    /// Depth-first search with an explicit stack instead of recursion,
    /// mutating `session` in place so its contents remain valid for a
    /// future continueSearching() call if this run pauses.
    private func runIterativeSearch(session: SearchSession, progress: SearchProgress, deadline: Date) -> SearchOutcome {
        while let topIndex = session.stack.indices.last {
            if progress.isCancelled { return .cancelled }
            if Date() >= deadline { return .pausedAtDeadline }

            guard !session.stack[topIndex].remainingMoves.isEmpty else {
                // No moves left to try from this level — back up one level.
                session.stack.removeLast()
                if !session.path.isEmpty { session.path.removeLast() }
                continue
            }

            let move = session.stack[topIndex].remainingMoves.removeLast()
            session.worker.restore(session.stack[topIndex].snapshot)
            guard session.worker.performMove(move, recordForUndo: false) else { continue }
            session.path.append(move)

            if session.worker.isWon { return .solved(path: session.path) }

            let key = stateKey(for: session.worker)
            if session.visited.contains(key) {
                session.path.removeLast()
                continue
            }
            session.visited.insert(key)
            progress.incrementExplored()
            session.stack.append(Frame(snapshot: session.worker.currentSnapshot(), remainingMoves: session.worker.legalMoves()))
        }
        return .exhausted
    }

    /// Stops an in-progress search early and discards it (unlike hitting
    /// the time limit, which pauses and stays resumable). The result
    /// becomes `.cancelled` once the search loop notices and unwinds.
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
