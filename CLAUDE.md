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

Key shape of the ruleset (see RULES.md for the authoritative version):
- 70-card deck: 4 colours x (2...King, no Aces) + trumps (0...21).
- 11-column tableau, middle column starts empty, 7 cards dealt to each of
  the other 10.
- Two trump foundations (build up from 0, build down from 21), four colour
  foundations (build up from 2), one single-card Reserve slot.
- Trumps auto-move to their foundation the instant they're exposed, even
  mid-drag. Colour cards only auto-move once a drag/drop resolves, and
  never while the Reserve is occupied.
- Same-colour or all-trump consecutive-rank runs can be dragged together.

## Status / important caveat

This code was written entirely in a cloud sandbox with **no Swift
toolchain and no macOS** — it has never been compiled or run. Do not
assume it builds cleanly. The first Xcode build on an actual Mac should be
treated as a debugging pass, not a working baseline. Pay particular
attention to:
- The drag-and-drop + mid-drag auto-move logic in `GameState.swift`
  (`beginDrag`, `endDrag`, `runTrumpAutoMoves`, `runFullAutoMoves`).
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
    Deck.swift                  deck construction/shuffle
    GameState.swift             game state, move + auto-move rules
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
