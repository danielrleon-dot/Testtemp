# Fortune's Foundation

A native macOS solitaire game built with Swift + SwiftUI, played with a 78-card
tarot deck (56 minor arcana across four suits, plus 22 major arcana). It's an
original variant inspired by tarot-card solitaire, not a clone of any
commercial title — the exact rules are documented below.

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

## Rules

- The deck has 4 minor-arcana suits (Wands, Cups, Swords, Pentacles), each
  ranked Ace...10, Page, Knight, Queen, King, plus 22 major arcana cards
  numbered 0 (The Fool) through 21 (The World).
- The tableau has 8 columns dealt with 1...8 cards each; the rest of the deck
  is the stock. Click the stock to flip a card to the waste pile.
- Four foundations build each minor suit up from Ace to King. A fifth
  foundation builds the major arcana in order from The Fool to The World.
- In the tableau, minor arcana cards build downward in alternating suit
  color (Wands/Swords vs. Cups/Pentacles); a valid descending run can be
  moved as a group. Major arcana cards can't have anything stacked on them
  in the tableau — they can only move to an empty column or straight to the
  major arcana foundation.
- Click a card to select it (and its movable run), then click a
  destination pile to move it there. Click the selected card again to
  deselect.
- Win by moving all 78 cards onto the five foundations.

## Project layout

```
Sources/FortunesFoundation/
  App.swift                    entry point
  Models/
    Suit.swift, MinorRank.swift, MajorArcana.swift, Card.swift   card model
    Deck.swift                 deck construction/shuffle
    GameState.swift            game state + move rules
  Views/
    ContentView.swift          top-level layout
    CardView.swift             single card rendering
    TableauColumnView.swift    tableau column
    PileViews.swift            foundations, stock, waste
```

## Note

This was written in an environment without access to a Swift toolchain or
macOS, so it hasn't been compiled or run yet — build it in Xcode first and
let me know if anything doesn't compile or feels off in play.
