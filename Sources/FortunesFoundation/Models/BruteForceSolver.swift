import Foundation

/// Searches for a winning move sequence from a given board, using either
/// of two strategies that share the same pause/resume/cancel machinery:
///
/// - **Depth-first** (`.depthFirst`): try a move, descend, backtrack if it
///   leads nowhere — pure exhaustive search, tries moves in a fixed order.
/// - **Best-first** (`.bestFirst`): keep a priority queue of every
///   frontier position seen so far, always expanding whichever one a
///   heuristic thinks is closest to a win next. Still exhaustive if run
///   to completion (an empty frontier still proves no solution exists),
///   but far more likely to *find* a solution quickly, at the cost of
///   holding many more candidate positions in memory at once (bounded by
///   `maxFrontierSize`, past which it pauses rather than growing forever).
///
/// Both are separate from SolitaireAI on purpose: this is exact search,
/// not a learned approximation. The heuristic best-first uses is its own
/// hand-crafted estimate (not the AI's evaluator), so it's just as useful
/// whether or not the AI has ever been trained.
///
/// This game's search space is astronomically large, so genuinely
/// exhaustive completion isn't realistic for most positions within any
/// human-scale time budget. A hard wall-clock time limit is required —
/// hitting it **pauses** the search rather than abandoning it: all
/// explored states and search progress are kept, and `continueSearching`
/// resumes exactly where it left off with a fresh time budget. Only an
/// explicit `cancel()` (or starting a new search) discards it.
///
/// Both searches are iterative (an explicit heap-allocated frontier), not
/// recursive: background DispatchQueue worker threads get a much smaller
/// default stack than the main thread, and a hard-to-solve board can
/// easily need thousands of moves of depth before backtracking — a
/// straightforward recursive version overflowed that stack in practice.
final class BruteForceSolver: ObservableObject {
    enum Strategy: String, CaseIterable, Identifiable {
        case depthFirst = "Basic"
        case bestFirst = "Smart"
        var id: String { rawValue }
    }

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

    /// Past this many pending positions, best-first search pauses rather
    /// than growing its frontier further — a safety valve against
    /// unbounded memory growth on a very long / very open search.
    private static let maxFrontierSize = 200_000

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

    /// One level of the depth-first search's explicit stack: the board
    /// state at this level, and the moves from it still left to try.
    private struct Frame {
        let snapshot: GameState.GameSnapshot
        var remainingMoves: [Move]
    }

    /// One entry in the best-first search's priority queue: a candidate
    /// position, the moves that reached it, and how promising it looks
    /// (lower is better — see `heuristic(for:)`).
    private struct Node {
        let snapshot: GameState.GameSnapshot
        let path: [Move]
        let heuristicValue: Double
    }

    /// Everything a search needs to resume exactly where it paused. A
    /// class (not a struct) so the background queue can mutate it in
    /// place across the lifetime of one solve()...continueSearching()...
    /// chain without it needing to flow back out through return values.
    /// Exactly one of the two frontier representations is populated,
    /// matching whichever Strategy the search was started with.
    private final class SearchSession {
        let worker: GameState
        var visited: Set<String>
        var dfsStack: [Frame]?
        var dfsPath: [Move]?
        var bestFirstHeap: MinHeap<Node>?

        init(worker: GameState, visited: Set<String>) {
            self.worker = worker
            self.visited = visited
        }
    }

    private enum SearchOutcome {
        case solved(path: [Move])
        case exhausted
        case pausedAtDeadline
        case cancelled
    }

    /// Starts a brand-new search from `game`'s current position, discarding
    /// any previously paused search. Runs on a background queue against
    /// its own scratch GameState — `game` itself is only read once (via a
    /// snapshot) and never touched again.
    func solve(from game: GameState, timeLimit: TimeInterval, strategy: Strategy) {
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

        let newSession = SearchSession(worker: worker, visited: visited)
        switch strategy {
        case .depthFirst:
            newSession.dfsStack = [Frame(snapshot: worker.currentSnapshot(), remainingMoves: worker.legalMoves())]
            newSession.dfsPath = []
        case .bestFirst:
            var heap = MinHeap<Node> { $0.heuristicValue < $1.heuristicValue }
            heap.insert(Node(snapshot: worker.currentSnapshot(), path: [], heuristicValue: heuristic(for: worker)))
            newSession.bestFirstHeap = heap
        }

        progress = newProgress
        session = newSession

        runCurrentSearch(timeLimit: timeLimit)
    }

    /// Resumes a search that paused after hitting its time limit or its
    /// frontier size cap, with a fresh time budget, using whichever
    /// strategy it was originally started with. Does nothing if there's no
    /// paused search to resume (e.g. it was cancelled, solved, or already
    /// exhausted).
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
            let outcome: SearchOutcome
            if session.dfsStack != nil {
                outcome = self.runDepthFirstSearch(session: session, progress: progress, deadline: deadline)
            } else {
                outcome = self.runBestFirstSearch(session: session, progress: progress, deadline: deadline)
            }
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
    private func runDepthFirstSearch(session: SearchSession, progress: SearchProgress, deadline: Date) -> SearchOutcome {
        guard var stack = session.dfsStack, var path = session.dfsPath else { return .exhausted }
        var outcome: SearchOutcome = .exhausted

        searchLoop: while let topIndex = stack.indices.last {
            if progress.isCancelled { outcome = .cancelled; break searchLoop }
            if Date() >= deadline { outcome = .pausedAtDeadline; break searchLoop }

            guard !stack[topIndex].remainingMoves.isEmpty else {
                // No moves left to try from this level — back up one level.
                stack.removeLast()
                if !path.isEmpty { path.removeLast() }
                continue
            }

            let move = stack[topIndex].remainingMoves.removeLast()
            session.worker.restore(stack[topIndex].snapshot)
            guard session.worker.performMove(move, recordForUndo: false) else { continue }
            path.append(move)

            if session.worker.isWon {
                outcome = .solved(path: path)
                break searchLoop
            }

            let key = stateKey(for: session.worker)
            if session.visited.contains(key) {
                path.removeLast()
                continue
            }
            session.visited.insert(key)
            progress.incrementExplored()
            stack.append(Frame(snapshot: session.worker.currentSnapshot(), remainingMoves: session.worker.legalMoves()))
        }

        session.dfsStack = stack
        session.dfsPath = path
        return outcome
    }

    /// Best-first (greedy) search: always expands whichever frontier
    /// position the heuristic currently rates most promising, rather than
    /// exploring in a fixed order. Still visits every reachable
    /// non-duplicate state if run to exhaustion (same completeness
    /// guarantee as depth-first — an empty frontier still proves no
    /// solution exists), just in a much more useful order in practice.
    private func runBestFirstSearch(session: SearchSession, progress: SearchProgress, deadline: Date) -> SearchOutcome {
        guard var heap = session.bestFirstHeap else { return .exhausted }
        var outcome: SearchOutcome = .exhausted

        searchLoop: while !heap.isEmpty {
            if progress.isCancelled { outcome = .cancelled; break searchLoop }
            if Date() >= deadline { outcome = .pausedAtDeadline; break searchLoop }
            if heap.count > Self.maxFrontierSize { outcome = .pausedAtDeadline; break searchLoop }
            guard let node = heap.popMin() else { break searchLoop }

            session.worker.restore(node.snapshot)
            if session.worker.isWon {
                outcome = .solved(path: node.path)
                break searchLoop
            }

            for move in session.worker.legalMoves() {
                session.worker.restore(node.snapshot)
                guard session.worker.performMove(move, recordForUndo: false) else { continue }

                let childPath = node.path + [move]
                if session.worker.isWon {
                    outcome = .solved(path: childPath)
                    break searchLoop
                }

                let key = stateKey(for: session.worker)
                if session.visited.contains(key) { continue }
                session.visited.insert(key)
                progress.incrementExplored()
                heap.insert(Node(snapshot: session.worker.currentSnapshot(), path: childPath, heuristicValue: heuristic(for: session.worker)))
            }
        }

        session.bestFirstHeap = heap
        return outcome
    }

    /// Estimated distance-to-win for a board: lower is more promising.
    /// Deliberately its own hand-crafted heuristic rather than the AI's
    /// evaluator — the solver needs to be useful even if the AI has never
    /// been trained (an untrained evaluator would score everything ~0 and
    /// make this ordering meaningless).
    private func heuristic(for game: GameState) -> Double {
        let cardsRemaining = Double(70 - game.foundationCardCount)
        let emptyColumns = Double(game.tableau.filter { $0.isEmpty }.count)
        let longestRun = Double(game.tableau.map(BoardFeatures.chainLength).max() ?? 0)
        let reservePenalty: Double = game.reserve == nil ? 0 : 1
        return cardsRemaining - 0.5 * emptyColumns - 0.3 * longestRun + reservePenalty
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

/// A minimal binary min-heap: `popMin()` always returns the element for
/// which `areInIncreasingOrder` ranks it lowest. Used by BruteForceSolver's
/// best-first search as its priority queue — a plain sorted array would
/// cost O(n) per insert/pop once the frontier grows large; this keeps both
/// O(log n).
private struct MinHeap<Element> {
    private var items: [Element] = []
    private let areInIncreasingOrder: (Element, Element) -> Bool

    init(areInIncreasingOrder: @escaping (Element, Element) -> Bool) {
        self.areInIncreasingOrder = areInIncreasingOrder
    }

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }

    mutating func insert(_ element: Element) {
        items.append(element)
        siftUp(from: items.count - 1)
    }

    mutating func popMin() -> Element? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let result = items.removeLast()
        if !items.isEmpty { siftDown(from: 0) }
        return result
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            guard areInIncreasingOrder(items[child], items[parent]) else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent
            if left < items.count, areInIncreasingOrder(items[left], items[candidate]) {
                candidate = left
            }
            if right < items.count, areInIncreasingOrder(items[right], items[candidate]) {
                candidate = right
            }
            guard candidate != parent else { return }
            items.swapAt(parent, candidate)
            parent = candidate
        }
    }
}
