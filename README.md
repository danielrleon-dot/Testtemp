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
    SolitaireAI.swift           self-play training loop, move suggestion
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
