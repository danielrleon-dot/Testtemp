# Game Rules

**Rules version: 1** — must match `GameState.rulesVersion` in
`Sources/FortunesFoundation/Models/GameState.swift`. Bump both together
whenever a change here changes what's legal or how the board behaves
(anything other than wording/typo fixes) — the game stamps every solved
puzzle it saves with this number, and uses a mismatch to tell "solved
under the current rules" apart from "solved under rules that no longer
apply," so a stale puzzle database doesn't silently corrupt AI training.
See `GameState.rulesVersion`'s doc comment and `PuzzleDatabase.
validRecords` for how that's used.

This file is the single source of truth for the game's rules. Edit it
whenever the rules change — the app should be kept in sync with whatever
is written here.

## Deck

- 4 colours (suits). Each colour has 12 cards: **2 to King** (no Aces) —
  2, 3, 4, 5, 6, 7, 8, 9, 10, Jack, Queen, King.
- 22 **trump** cards, numbered **0 to 21**. Trumps have no colour.
- Total: 4 × 12 + 22 = **70 cards**.

## Board layout

- **11 columns** in the tableau. The **middle column (6th)** starts empty.
- The other 10 columns are dealt an equal number of cards at random:
  70 cards ÷ 10 columns = **7 cards per column**.
- All cards are dealt face up and stay visible at all times — stacking is
  offset vertically (like a cascade) so every card's colour/number stays
  readable, nothing is ever hidden face-down.
- Within a column, cards are stacked with the first-dealt card at the top
  of the visual stack and each later card cascading below it. The
  **last card in a column (visually at the bottom) is the "apparent" /
  active card** — the one available to move or drag.

## Objective

Get rid of all 70 cards by moving them into the receiving slots at the
top of the screen.

## Receiving slots (7 total)

1. **Bottom Trump Slot** — builds trumps **up** starting from 0.
2. **Top Trump Slot** — builds trumps **down** starting from 21.
3. **Colour Slot** (×4, one per colour) — builds that colour **up**
   starting from 2 through King.
4. **Reserve Slot** — holds **exactly one card**, of any kind. You can
   never stack on the Reserve. It can be emptied by moving its card into
   an open tableau slot (see below), or by the automatic rules sending it
   to a foundation.

## Automatic moves

Cards can leave the tableau or the Reserve automatically, without the
player dragging them, whenever they are "apparent" (i.e. the active card
at the bottom of a tableau column, or the card sitting in the Reserve).

Trumps and colour cards are checked the same way for **when** this
happens: nothing auto-moves while a card is still actively mid-drag.
The check only runs once the currently-dragged card has been **dropped
somewhere** — into a tableau column, into the Reserve, or into one of the
foundation slots — no matter where it lands.

### Trumps

- An apparent trump **0** always auto-moves to the Bottom Trump Slot.
- An apparent trump **21** always auto-moves to the Top Trump Slot.
- An apparent trump auto-moves to the **Bottom Trump Slot** whenever its
  number is exactly **one more** than the current top card of the Bottom
  Trump Slot.
- An apparent trump auto-moves to the **Top Trump Slot** whenever its
  number is exactly **one less** than the current top card of the Top
  Trump Slot.

### Colour cards

- An apparent **2** of a colour always auto-moves to that colour's slot.
- An apparent card of rank *N* (N > 2) in a colour auto-moves to that
  colour's slot whenever the slot's current top card is rank *N − 1*.
- Colour auto-moves are **suspended** entirely whenever there is a card
  in the Reserve. They resume only once the Reserve's card has been
  placed into a free tableau slot (an empty column).

### Reserve

- The card sitting in the Reserve is itself "apparent" and is checked
  against the same auto-move rules above (trump or colour) as any
  tableau card.

## Manual moves (dragging)

### You only ever grab the bottom card

**You can only drag the apparent (bottom-most) card of a column, or the
card in the Reserve.** Grabbing anything else — a card in the middle of
the column, or anywhere that isn't the apparent card — isn't a valid
grab; nothing happens. There's no way to grab "further up" a column to
pick up more than one card at once — what actually moves is decided by
**where you drop it**, not by what you grabbed.

### Where it can be dropped, and what comes with it

- Drop the card onto the **Reserve** (only possible if it's empty): the
  card **always** goes there alone, regardless of the option below —
  nothing else from its column ever follows it onto the Reserve, since
  the Reserve can only ever hold one card.
- Drop the card onto an **empty tableau column**, or **on top of another
  apparent card that's the same kind and exactly one rank away** ("just
  above or below" — a colour card onto the same colour, a trump onto
  another trump): the dragged card is placed there, and then — **only if
  the "drag whole column" option is turned on** — the rest of the run
  behind it follows too (see below). With the option off, only the
  single dragged card ever moves, no matter what's behind it.
- The foundation slots only ever accept a single card, and only the
  dragged card itself — never anything following behind it.

### "Drag whole column" option

The player can tick a **"drag whole column"** option (a checkbox in the
game's toolbar). It changes what happens once the dragged card is
successfully placed on a tableau column:

- **Off** (default): only the single card you dragged ever moves.
- **On**: whatever run of consecutive-rank, same-colour-or-all-trump
  cards was sitting directly behind the dragged card (still in its
  original column) gets pulled along automatically and stacked on top of
  it, in order — as if you'd dragged each of them there yourself, one at
  a time, right after the first. If nothing behind it chains that way,
  only the single card moves regardless.

This option only affects tableau destinations — dropping onto the
Reserve always takes the single card alone either way.

### This inverts the run at the destination

When the whole-column option pulls a run along, the dragged card lands
first and the rest of its old run follows on top of it one at a time, so
**the run ends up inverted at the destination**: the card you actually
dragged ends up buried at the bottom of the new stack, and whatever card
was furthest from it in the original column (the "top" of that run)
becomes the new apparent card.

## Open questions / assumptions to confirm

These are implementation assumptions made while transcribing the rules —
flag if any are wrong so this file (and the game) can be corrected:

- "Just above or below" for stacking is read as **rank differs by
  exactly 1**, in either direction (so building runs can go up or down
  freely, unlike classic solitaire's single-direction rule).
- "A free slot in the tableau" for emptying the Reserve is read as any
  **empty column** (including the middle column once it's been vacated
  again, or any column fully cleared during play).
- The "drag whole column" option defaults to **off** — confirm that's the
  right default (vs. defaulting on).
