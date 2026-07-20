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
- Drop it onto the Reserve and it moves **alone**. Drop it onto an empty
  column, or onto another card one rank away of the same colour (or
  another trump one number away), and **the rest of the run behind it
  follows automatically** — landing inverted, with the card you dragged
  ending up buried at the bottom and the far end of the run becoming the
  new exposed card.
- Trump 0 and 21, and any trump that's the next needed card for either
  trump foundation, auto-move there once a drag ends — never mid-drag.
  Colour cards auto-move the same way, but never while a card sits in the
  Reserve.
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

Most of this was originally written in an environment without access to a
Swift toolchain or macOS. It's since been built and run on a real Mac, and
a few bugs found there have already been fixed — but if something doesn't
compile or feels off in play, say so.
