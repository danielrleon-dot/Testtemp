# Solitaire

A native macOS solitaire game built with Swift + SwiftUI, using a custom
70-card ruleset (4 colours 2...King plus trumps 0...21, an 11-column
tableau, dual trump foundations, and a single-card Reserve). The full rules
live in [`RULES.md`](RULES.md) — edit that file to change the rules; the
game logic in `Sources/FortunesFoundation/Models/GameState.swift` should be
kept in sync with it.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (or the Swift 5.9+ command line toolchain)

## Running it

**Xcode:**
1. Open `Package.swift` in Xcode (File > Open, select this folder).
2. Choose the `FortunesFoundation` scheme and press Run (⌘R).

**Command line:**
```
swift run
```

## Playing

- You can only drag the exposed (bottom-most) card of a tableau column, or
  the card in the Reserve — never a card further up a column.
- Drop it onto the Reserve and it always moves **alone**. Drop it onto an
  empty column, or onto another card one rank away of the same colour (or
  another trump one number away), and — if the **"Drag whole column"**
  checkbox in the toolbar is ticked — the rest of the run behind it
  follows automatically, landing inverted (the card you dragged ends up
  buried at the bottom, the far end of the run becomes the new exposed
  card). With the checkbox off (the default), only the single card moves.
- Trump 0 and 21, and any trump that's the next needed card for either
  trump foundation, auto-move there once a drag ends — never mid-drag.
  Colour cards auto-move the same way, but never while a card sits in the
  Reserve.
- Win by clearing all 70 cards onto the seven foundations.

See `RULES.md` for the full, precise ruleset.

## Seeds and undo/redo

- Every deal is shuffled from a **seed** (a plain number), shown next to
  "Seed:" in the toolbar. Note it down to come back to the same deal
  later — paste it into the "Replay a seed" field and press **Play Seed**.
  "New Game" always picks a fresh random seed.
- **Undo** / **Redo** step back and forward through the game one move at a
  time (a manual placement plus whatever auto-moves followed from it
  counts as one move). Both can be pressed repeatedly. Undo history is
  cleared by starting a new game (new or replayed seed).

## AI

The "AI" row has a self-play reinforcement-learning agent:

- **Train 200 games** runs 200 games of the AI playing itself in the
  background (separate, disposable boards — it never touches the game
  you're currently playing), learning after every move via TD(0) — it's a
  linear value function over a handful of board features (foundation
  progress, empty columns, longest movable run, etc.), not a neural
  network, so it trains fast without any ML framework dependency. Press
  it repeatedly to keep training; learned weights persist across app
  launches (`UserDefaults`), and the win-rate counter accumulates.
- **AI Move** applies the AI's current best move to *your* game, once,
  using whatever it's learned so far (no further training from this).
- Expect **modest** results, especially before much training — this is a
  genuine but simple learner, not a solver. It should trend toward better
  foundation progress with more training, but a linear evaluator likely
  won't reliably win full games. See `Models/SolitaireAI.swift` for the
  self-play loop and `Models/BoardEvaluator.swift` for the learning rule.

## Solver

The "Solver" row is a **separate** tool from the AI: exact search for a
winning move sequence from the game currently on screen — no learning, no
approximation. It offers two strategies:

- **Basic** — pure depth-first search with backtracking (try a move,
  descend, backtrack if it leads nowhere), trying moves in a fixed order.
- **Smart** — best-first search: keeps a priority queue of every
  candidate position found so far, always expanding whichever one a
  heuristic (cards home, empty columns, longest movable run, whether the
  Reserve is free) rates closest to a win next, instead of a fixed order.
  Much more likely to find a solution before the time limit, at the cost
  of holding more candidate positions in memory at once — past 200,000
  pending positions it **pauses** rather than growing unbounded, exactly
  like hitting the time limit (see below). It never discards a candidate
  to stay under that cap; discarding would risk wrongly reporting "no
  solution exists" for a puzzle that's actually solvable, just not yet
  fully explored.

Both skip re-exploring a board position already proven fruitless earlier
in the same search (that doesn't skip any reachable win, just redundant
re-exploration — including recognizing that two boards differing only by
*which* empty column a spare card happens to be parked in are really the
same position), and both are still exhaustive if given enough time — an
empty search space proves no solution exists either way.

- Pick a **strategy** and a **time limit** (10s/30s/60s/2m), then
  **Solve Current Game**. It searches in the background — your board
  stays interactive.
- This game's search space is astronomically large, so most positions —
  especially with Basic, and especially at 10-30s — will very likely just
  hit the time limit rather than reach a definitive answer. Hitting it
  **pauses** the search rather than throwing it away — press **Continue**
  to keep going with another time budget, picking up exactly where it
  left off (explored states and all), instead of starting over from
  scratch. Keep pressing Continue to keep accumulating search time.
- If it finds a win, **Play Next Move** steps through the solution on
  your actual board, one move at a time (through the normal Undo-tracked
  path, so you can undo it like any other move).
- **Stop** cancels an in-progress search and discards it — unlike hitting
  the time limit, this is not resumable. Starting a new "Solve Current
  Game" also discards any paused search.
- Every puzzle it solves is automatically saved to a growing on-disk
  database (see "Train from Puzzles" below) — solving is itself how you
  build up training data for the AI. Each solved puzzle is tagged with
  the rules version it was solved under; if `RULES.md` ever changes,
  puzzles solved under the old rules are permanently discarded the next
  time the app launches, rather than quietly teaching the AI an outdated
  game.

## AI

The "AI" row has a self-play reinforcement-learning agent:

- **Train 200 games** runs 200 games of the AI playing itself in the
  background (separate, disposable boards — it never touches the game
  you're currently playing), learning after every move via TD(0) — it's a
  linear value function over a handful of board features (foundation
  progress, empty columns, longest movable run, etc.), not a neural
  network, so it trains fast without any ML framework dependency. Press
  it repeatedly to keep training; learned weights (and the lifetime
  training count, shown alongside this session's win rate) persist across
  app launches (`UserDefaults`).
- **AI Move** applies the AI's current best move to *your* game, once,
  using whatever it's learned so far (no further training from this).
- **Train from Puzzles** trains from every puzzle the Solver has proven
  winnable (stored on disk, count shown next to the button) — supervised
  learning from real, known wins rather than self-play guesswork. Each
  solved path is replayed and trained on backward from the win, so every
  step's target value is an exact computed return instead of a self-play
  estimate. This is a *much* stronger signal than self-play, so solving
  even a handful of puzzles and training from them is worth trying before
  judging the AI's strength. Complements self-play rather than replacing
  it — the two share the same underlying weights, and can both keep
  contributing over time as you solve more puzzles. If `RULES.md` ever
  changes, puzzles solved under the old rules are dropped from this count
  (and the file on disk) automatically the next time the app launches,
  since their moves may no longer even be legal — you'd need to re-solve
  them under the new rules to get that training data back.
- Expect **modest** results from self-play alone, especially before much
  training — this is a genuine but simple learner, not a solver (that's
  what the Solver above is for). It should trend toward better foundation
  progress with more training, but a linear evaluator likely won't
  reliably win full games from self-play signal alone. See
  `Models/SolitaireAI.swift` for both training loops and
  `Models/BoardEvaluator.swift` for the learning rule.
- **One-time reset**: earlier training data showed the evaluator's
  weights had drifted to an unusable, astronomically large state (a
  numerical instability in the learning rule, now fixed — features are
  normalized, a redundant feature was removed, the learning rate now
  decays, and weights are clamped to a sane range as a backstop). The
  next launch after this fix starts the AI's weights and lifetime
  training count over from zero — previously trained weights aren't
  salvageable, so this is a clean slate rather than lost progress worth
  preserving. Solved puzzles and self-play from here on will retrain it
  correctly.
- Every training run (either button) appends a record — timestamp,
  training kind, the evaluator's full weight vector, and (for self-play)
  that run's win/loss counts — to a JSON log at
  `~/Library/Application Support/Solitaire/TrainingLog.json`. There's no
  in-app viewer for it; it's there so you can export the file and get an
  outside review of how the weights evolved alongside the win rate,
  rather than only ever seeing the current weights in isolation.

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
    TrainingLogEntry.swift      one training-run record (weights + outcome)
    TrainingLog.swift           on-disk history of training runs
  Views/
    ContentView.swift           top-level layout
    CardView.swift               single card rendering
    TableauColumnView.swift     tableau column + drag source
    ReserveView.swift           reserve slot + drag source
    FoundationViews.swift       trump + colour foundation slots
    DraggedStackView.swift      floating card(s) while dragging
    TargetFrame.swift           drop-target frame tracking (hit-testing)
```

## Note

Most of this was originally written in an environment without access to a
Swift toolchain or macOS. It's since been built and run on a real Mac, and
a few bugs found there have already been fixed — but if something doesn't
compile or feels off in play, say so.
