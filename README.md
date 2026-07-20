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

- Drag the exposed (bottom-most) card of any tableau column, or the card in
  the Reserve, onto another card one rank away of the same colour (or
  another trump one number away), or onto an empty column.
- If several cards at the bottom of a column form a same-colour or
  all-trump consecutive-rank run, grab the bottom card and the whole run
  drags together.
- Trump 0 and 21, and any trump that's the next needed card for either
  trump foundation, fly there automatically the instant they're exposed —
  even mid-drag. Colour cards auto-move to their foundation once a drag
  ends, but never while a card sits in the Reserve.
- Win by clearing all 70 cards onto the seven foundations.

See `RULES.md` for the full, precise ruleset.

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
    CardView.swift               single card rendering
    TableauColumnView.swift     tableau column + drag source
    ReserveView.swift           reserve slot + drag source
    FoundationViews.swift       trump + colour foundation slots
    DraggedStackView.swift      floating card(s) while dragging
    TargetFrame.swift           drop-target frame tracking (hit-testing)
```

## Note

This was written in an environment without access to a Swift toolchain or
macOS, so it hasn't been compiled or run yet — build it in Xcode first and
let me know if anything doesn't compile or feels off in play.
