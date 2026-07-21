# CLAUDE.md

Context for Claude Code (or any Claude session) working in this repository.

## Project identity

- **Repo**: `danielrleon-dot/testtemp`
- **Project**: a native macOS solitaire game, Swift + SwiftUI, built as a
  Swift Package (executable target `FortunesFoundation`).
- **Branch this was built on**: `claude/new-project-qi8x15`. If that branch
  has since merged, treat `main` (or whatever succeeded it) as current and
  this note as historical.
- This is **not** the real commercial "Fortune's Foundation" tarot
  solitaire — it started as a loose homage, then was fully replaced with
  the player's own custom ruleset (see below). The target/app name
  `FortunesFoundation` is a legacy naming artifact, not a rules reference.

## Rules — read this first

**`RULES.md` at the repo root is the single source of truth for game
rules.** It was dictated by the project owner and is meant to be edited
directly whenever the rules change.

The rules are implemented in
`Sources/FortunesFoundation/Models/GameState.swift`. There is no automated
check that the two stay in sync — if you change one, update the other by
hand, and call out any mismatch you notice.

Both carry a **rules version number** (`GameState.rulesVersion`, mirrored
at the top of `RULES.md`) that must be bumped by hand alongside any actual
rules change (not cosmetic edits) — every `SolvedPuzzleRecord` is stamped
with it, and `PuzzleDatabase` uses a mismatch to keep puzzles solved under
an old ruleset from silently corrupting AI training after the rules
change. See the Puzzle database section below.

Key shape of the ruleset (see RULES.md for the authoritative version):
- 70-card deck: 4 colours x (2...King, no Aces) + trumps (0...21).
- 11-column tableau, middle column starts empty, 7 cards dealt to each of
  the other 10.
- Two trump foundations (build up from 0, build down from 21), four colour
  foundations (build up from 2), one single-card Reserve slot.
- Trumps and colour cards both only auto-move once a drag/drop resolves
  (never mid-drag), regardless of which pile the dragged card lands in.
  Colour auto-moves are additionally suspended while the Reserve is
  occupied.
- Only the apparent (bottom) card of a column, or the Reserve's card, can
  ever be grabbed — never a card further up. Dropping onto the Reserve
  always takes that one card alone. Dropping onto a tableau column (empty
  or a matching card) additionally pulls the rest of the matching
  same-colour/all-trump run along behind it, landing **inverted** (the
  dragged card ends up buried at the bottom of the new stack; the far end
  of the run becomes the new apparent card) — but only if the player has
  the **"drag whole column"** checkbox (`GameState.moveWholeColumn`,
  default off) turned on. With it off, every drag moves a single card.

Two things that aren't gameplay rules but are core to how the app works:
- Every deal is shuffled deterministically from a `UInt64` seed
  (`SeededGenerator`, SplitMix64), shown in the toolbar so the player can
  replay a specific deal via `newGame(seed:)`.
- Undo/redo is snapshot-based, not command-based: `GameState` pushes a
  full copy of the board (`GameSnapshot`) onto `undoStack` right before
  each successful `endDrag` placement, and `runFullAutoMoves()`'s
  resulting cascade is *not* snapshotted separately — one Undo press
  reverts a manual move and everything it auto-triggered as a single
  unit. Any new move clears `redoStack`.

## AI (SolitaireAI)

A real (if intentionally simple) reinforcement-learning agent, added at
the project owner's request. Since this game has no opponent and no
hidden information once dealt, "learning" here is self-play TD(0) over a
**linear** value function (`BoardEvaluator`) on hand-crafted features
(`BoardFeatures`) — deliberately not a neural network, so it trains fast
on-device with zero ML framework dependency and stays easy to reason
about without a compiler to check it.

- `GameState.legalMoves()` / `GameState.performMove(_:recordForUndo:)` /
  `GameState.currentSnapshot()` / `GameState.restore(_:)` are the
  non-private "headless" API surface the AI needs, alongside the existing
  gesture-driven `beginDrag`/`endDrag` path used by human play — both
  ultimately call the same private `canPlace`/`place`/`placementGroup`
  helpers, so there's one source of truth for what's legal.
- `SolitaireAI.train(episodes:)` runs self-play games on a background
  `DispatchQueue`, each against its own disposable `GameState(seed:)` —
  it never touches the player's live game. Weight updates happen on that
  background queue too (the `evaluator` itself is plain, not
  `@Published`, specifically so it's not touched from two threads via
  Combine); only the summary `@Published` stats hop back to the main
  thread when a training run finishes.
- Exploration rate decays with `totalEpisodesTrained` (0.15 → floor 0.02,
  see `explorationRate(afterEpisodes:)`), not a fixed constant — a fixed
  rate keeps sabotaging otherwise-good, near-complete games forever.
  `totalEpisodesTrained` is lifetime, persisted separately from the
  per-launch `gamesPlayed`/`gamesWon` session counters.
- `SolitaireAI.suggestMove(for:)` runs synchronously on the caller's
  thread (expected: main, via the "AI Move" button) and scores every
  legal move by actually applying it to the passed-in live `GameState`,
  reading the resulting value, then rolling it back via
  snapshot/restore — so evaluation never leaves a trial move in place.
- `SolitaireAI.trainFromSolvedPuzzles(_:)` is supervised training from
  `SolvedPuzzleRecord`s the solver has actually proven winnable (see
  below) — a much stronger signal than self-play, since every state on
  the path is *known* to lead to a real win. `trainFromSolvedPuzzle(_:)`
  replays one record and walks it **backward** from the win, so each
  step's TD target is an exact computed return (reward + discount ×
  next step's already-known target) rather than a self-play bootstrap
  estimate that needs several passes to settle. Shares `isTraining` and
  `evaluator` with self-play — same weights, same guard against running
  concurrently — so the two are complementary, not separate models.
- Expect modest performance from self-play alone, especially before much
  training — this is meant as a working foundation to keep improving
  (better features, a neural net, prioritized self-play, etc.), not a
  finished solver on its own. Training from solved puzzles (see below)
  is a meaningfully stronger lever than more self-play episodes.

## Solver (BruteForceSolver)

Deliberately **separate** from SolitaireAI — a different kind of tool
(exact search vs. a learned approximation), not a competing
implementation of it. Two interchangeable strategies, chosen at
`solve()` time via `Strategy`, sharing everything else (pause/resume,
cancellation, undo-tracked playback):

- `.depthFirst` (UI: "Basic") — the original approach: an explicit
  `[Frame]` stack, try a move, descend, backtrack, trying moves in
  whatever order `legalMoves()` produces.
- `.bestFirst` (UI: "Smart") — a priority queue (`MinHeap<Node>`, a
  hand-rolled binary heap — Swift has no stdlib priority queue) ordered
  by `heuristic(for:)`, always expanding the most-promising-looking
  frontier position next instead of a fixed order. The heuristic
  (cards remaining, empty columns, longest movable run, Reserve
  occupancy) is deliberately **its own**, not SolitaireAI's evaluator —
  an untrained evaluator scores everything ~0, which would make the
  ordering meaningless. Bounded by `maxFrontierSize` (200,000) as a
  memory safety valve, since unlike the DFS stack (bounded by search
  depth) the frontier can otherwise grow very large. This cap has gone
  through two buggy designs before landing on the current one, both
  found through real play on the project owner's Mac:
  1. A hard cap (stop everything once over the limit) checked *before*
     popping anything: `continueSearching()` would immediately re-hit the
     same full-frontier check and re-pause with zero progress, since
     nothing had shrunk it yet — "Continue" looked like it did nothing.
  2. The fix for that made it a *soft* cap instead: past the limit, new
     candidates simply stopped being inserted while existing ones kept
     getting popped/expanded, so the frontier would shrink back down over
     time. This introduced a worse bug: those skipped candidates were
     discarded, not deferred, so if the frontier later drained to empty
     it exited the loop and reported "no solution exists" — a **false
     negative**. The project owner hit this directly: "i managed to solve
     a puzzle that the solver said could not be solved."
  The current design fixes both: the cap is checked exactly once per
  outer loop iteration, *after* a node has been fully expanded (so
  `continueSearching()` always makes at least that much progress before
  possibly re-pausing), and when triggered it **pauses the whole search**
  rather than dropping any candidate — nothing already in the frontier is
  ever discarded, so an eventual empty frontier remains a sound proof
  that no solution exists.

Both are exhaustive if run to completion — an empty frontier proves no
solution exists either way — and both only prune by skipping board
positions already proven fruitless earlier in the *same* search
(`stateKey(for:)`, a canonical string over every pile in order — order
matters for legality, so it's not just set membership). That doesn't
skip any reachable win, just redundant re-exploration.

- Requires a hard wall-clock time limit (the project owner explicitly
  asked for this) — this game's search space is large enough that
  genuine exhaustive completion isn't realistic for most positions.
  Hitting the deadline **pauses** rather than abandons the search (see
  below) — the UI calls it "paused... inconclusive so far," not
  "unsolvable."
- `SearchSession` (worker `GameState` + `visited`, plus either
  `dfsStack`/`dfsPath` or `bestFirstHeap` depending on strategy) and the
  `SearchProgress` counter are both kept alive across a pause instead of
  being recreated, specifically so `continueSearching(timeLimit:)` can
  resume with the exact same explored-state set and frontier, plus a
  fresh deadline — not a restart. Only `cancel()` (Stop) or starting a new
  `solve()` discards them; hitting the deadline does not.
  `cumulativeElapsedSeconds` likewise accumulates across pause/continue
  rather than resetting per run.
- Runs on its own background `DispatchQueue`, entirely against a scratch
  `GameState` restored from a snapshot of the player's board — never
  mutates the live game during the search itself.
- Both searches (`runDepthFirstSearch`, `runBestFirstSearch`) are
  iterative with an explicit heap-allocated frontier, not recursive. A
  first version used plain recursion and crashed with `EXC_BAD_ACCESS` on
  real hardware — background `DispatchQueue` worker threads get a much
  smaller default stack than the main thread, and this game can need
  thousands of moves of depth before backtracking, which overflowed it.
  Don't reintroduce recursion here without solving that problem some
  other way (e.g. a dedicated `Thread` with an explicit larger
  `stackSize`).
- Progress (`statesExplored`, `elapsedSeconds`) crosses threads via a
  small lock-backed `SearchProgress` class polled by a main-thread
  `Timer`, not raw shared-state access — the search loop runs as one
  long synchronous closure on its queue, so a `DispatchQueue.sync` read
  from the main thread would block until the whole search finished,
  which is why this needed an actual lock instead.
- If a solution is found, `playNextSolutionMove(in:)` applies it to the
  live game one step at a time (through the same undo-tracked
  `performMove` path as everything else), so the player can watch it
  play out and still undo it afterward.
- `solvedSeed`/`solvedStartingSnapshot` capture what `solve()` was called
  with (not wherever a later pause happened to land), so a solution found
  after one or more `continueSearching()` calls still records the actual
  starting position. `ContentView` observes `solver.status` via
  `.onChange` and turns a `.solved` transition into a `SolvedPuzzleRecord`
  appended to `PuzzleDatabase` — the solver itself doesn't know the
  database exists, keeping the two independently testable.

## Puzzle database (SolvedPuzzleRecord / PuzzleDatabase)

Bridges the Solver and the AI: every puzzle the Solver proves winnable is
persisted (seed + starting `GameState.GameSnapshot` + winning `[Move]` +
`rulesVersion`) to a JSON file under Application Support, growing across
app launches. This is what `SolitaireAI.trainFromSolvedPuzzles(_:)` trains
from. The starting *snapshot* is authoritative for replay, not just the
seed — `solve()` can be invoked from any board the player has open, not
only a freshly dealt one, so seed-only replay wouldn't always reproduce
it. `GameState.GameSnapshot`, `PileLocation`, and `Move` are all `Codable`
specifically to support this persistence.

Every record is stamped with the `GameState.rulesVersion` in effect when
it was solved. `PuzzleDatabase.validRecords` filters to only records whose
`rulesVersion` matches the *current* `GameState.rulesVersion` — that's
what `trainFromSolvedPuzzles` and the "Train from Puzzles" button actually
use, not the raw `records` array. A record stamped with an older version
predates a rules change: its move sequence might not even replay legally
anymore, and even where it happens to, it no longer reflects how the game
is actually played, so training on it would actively teach the AI stale
behaviour rather than just being a missed opportunity. Stale records are
never deleted (`PuzzleDatabase.staleRecordCount` surfaces the count in the
UI instead) — they're evidence of real solved work, just not safe to
learn from until/unless someone confirms they still apply. Records
persisted before this versioning existed decode with `rulesVersion == 0`
(`SolvedPuzzleRecord.init(from:)`), which can never match a real
`GameState.rulesVersion` (starts at 1), so old databases degrade to "all
stale" rather than crashing on load or silently passing as current.

## Status / important caveat

This code was originally written entirely in a cloud sandbox with **no
Swift toolchain and no macOS**. It has since been built and run
successfully on the project owner's Mac (Xcode 26.6), with a few real
bugs already found and fixed there (see git log) — but most work on this
repo is still done blind, without a Swift toolchain, so don't assume new
changes build cleanly until confirmed on a Mac. Pay particular attention
to:
- The drag-and-drop + auto-move logic in `GameState.swift`
  (`beginDrag`, `endDrag`, `runFullAutoMoves`).
- The frame-based drop-target hit-testing in `Views/TargetFrame.swift`
  (`TargetFramePreferenceKey` + `.reportFrame(_:)`), which the drag
  gestures in `TableauColumnView.swift` / `ReserveView.swift` rely on.

## Requirements & running it

- macOS 13 (Ventura)+, Xcode 15+ (or Swift 5.9+ CLI toolchain).
- Xcode: open `Package.swift`, select the `FortunesFoundation` scheme, ⌘R.
- CLI: `swift run` from the repo root.

## Project layout

```
Sources/FortunesFoundation/
  App.swift                    entry point
  Models/
    Colour.swift, ColourRank.swift, Card.swift   card model
    PileLocation.swift          identifies each pile/slot
    Move.swift                  a candidate move (source/destination/run)
    Deck.swift                  deck construction/shuffle
    SeededGenerator.swift       deterministic RNG for reproducible deals
    GameState.swift             game state, move/auto-move rules, undo/redo
    BoardFeatures.swift         hand-crafted features for the AI
    BoardEvaluator.swift        linear value function + TD(0) update
    SolitaireAI.swift           self-play + puzzle-based training, move suggestion
    BruteForceSolver.swift      exhaustive search for a winning sequence
    SolvedPuzzleRecord.swift    a solved puzzle (seed + start + moves)
    PuzzleDatabase.swift        on-disk store of solved puzzles
  Views/
    ContentView.swift           top-level layout
    CardView.swift              single card rendering
    TableauColumnView.swift     tableau column + drag source
    ReserveView.swift           reserve slot + drag source
    FoundationViews.swift       trump + colour foundation slots
    DraggedStackView.swift      floating card(s) while dragging
    TargetFrame.swift           drop-target frame tracking (hit-testing)
```

See `README.md` for a player-facing quick-start and `RULES.md` for the
full ruleset.
