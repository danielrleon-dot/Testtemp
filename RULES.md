# Game Rules

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

- You may drag the apparent card of any column, or the card in the
  Reserve, to:
  - an **empty tableau column** (any card may go there), or
  - **on top of another apparent card**, if that target card is of the
    same kind and **exactly one rank away** ("just above or below"):
    - a **colour card** can only be placed on another card of the
      **same colour**, one rank higher or lower.
    - a **trump** can only be placed on another **trump**, one number
      higher or lower.
- You may also drag a **run of cards** from the bottom of a column
  together, by grabbing the apparent (bottom-most) card, **provided the
  cards being dragged form a consecutive rank sequence** (each adjacent
  to the next) and are **either**:
  - all the **same colour**, or
  - all **trumps**.

  Drop the whole run:
  - onto an empty column, or
  - onto another apparent card that is one rank away from the run's
    leading (bottom-most / apparent) card, following the same
    same-colour / trumps-on-trumps rule as single-card placement.

## Open questions / assumptions to confirm

These are implementation assumptions made while transcribing the rules —
flag if any are wrong so this file (and the game) can be corrected:

- "Just above or below" for stacking is read as **rank differs by
  exactly 1**, in either direction (so building runs can go up or down
  freely, unlike classic solitaire's single-direction rule).
- "A free slot in the tableau" for emptying the Reserve is read as any
  **empty column** (including the middle column once it's been vacated
  again, or any column fully cleared during play).
